/*
	LTOVRBPF.h

	Copyright (C) 2012 Michael Fort, Paul C. Pratt

	You can redistribute this file and/or modify it under the terms
	of version 2 of the GNU General Public License as published by
	the Free Software Foundation.  You should have received a copy
	of the license along with this file; see the file COPYING.

	This file is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	license for more details.
*/

/*
	LocalTalk OVeR Berkeley Packet Filter
*/


#define BPF_dolog (dbglog_HAVE && 0)

/* BPF and devices */
static unsigned char device_address[6] = {
	0
};
static unsigned int device_buffer_size = 0;
static int fd = -1; /* BPF file descriptor */
static struct bpf_version bpf_version;
static struct bpf_program bpf_program;
static struct bpf_insn insns[] =
{
	/* Program for BPF to filter out non-LTOE packets */
	BPF_STMT(BPF_LD + BPF_H + BPF_ABS, 12),
	BPF_JUMP(BPF_JMP + BPF_JEQ + BPF_K, 0x809B, 0, 1),
	BPF_STMT(BPF_RET + BPF_K, 65535),
	BPF_STMT(BPF_RET + BPF_K, 0),
};

/*
	Transmit buffer that is reused from tx packet to tx packet.
	The 's' byte represents the source mac address (ours) and we don't
	have to initialize it because the MAC device will automatically
	fill it in for us.  The four 'p' bytes represent the process number
	of this Mini vMac application.  It helps differentiate packets
	between two applications running on the same machine.  It is not
	used at this time.  There is a small chance two applications could
	get the same LLAP/SDLC address to start with and would not work
	correctly (1 in 254). The 'S' bytes are the size of the LLAP packet
	since it can be smaller than the minimum sized Ethernet frame.
	The process number is replaced at initialization.  The size is
	updated just before sending to BPF.  All LLAP data is inserted
	starting at byte 20.
*/
static unsigned char tx_buffer[20 + LT_TxBfMxSz] =
	"\xFF\xFF\xFF\xFF\xFF\xFFssssss\x80\x9BppppSS";

/* Macro used by only the get_sockaddrs function for readability. */
#define ROUNDUP(a, size) \
	(((a) & ((size) - 1)) ? (1 + ((a) | ((size) - 1))) : (a))

/*
	Utility function needed for walking the addresses of the
	kernel route lookup
*/
LOCALPROC get_sockaddrs(int addrs, struct sockaddr* sa,
	struct sockaddr** rti_info)
{
	int loop;
	int incr;

	for (loop = 0; loop < RTAX_MAX; loop++) {
		if (addrs & (1 << loop)) {
			rti_info[loop] = sa;
			incr = sa->sa_len ? ROUNDUP(sa->sa_len, sizeof(uint32_t))
				: sizeof(uint32_t);
			sa = (struct sockaddr*)((unsigned long int)sa + incr);
		} else {
			rti_info[loop] = NULL;
		}
	}
}

/*
	This ugly function does a lot of steps to prepare the BPF
	for our use.
	1. Find the ethernet interface that the default route uses.
	2. Determine the maximum number of BPF devices can exist.
	3. Search for a usable BPF device and open it.
	4. Set the BPF device to use our ethernet interface.
	5. Get the proper buffer size to use with the BPF device.
	6. Set some useful modes of operation on the BPF device.
	7. Install a program on the device that filters out non-LTOE
	packets.
*/

LOCALFUNC int get_ethernet(void)
{
	int result;
	ssize_t io_count;
	int size;
	struct rt_msghdr* message = NULL;
	struct sockaddr_in* addrs;
	struct sockaddr* sa_list[RTAX_MAX];
	struct sockaddr* sa;
	struct sockaddr_dl* link;
	int namelen;
	int loop;
	char filename[64];
	struct ifreq ifreq;
	int enable = 1;
	int max;
	size_t len = sizeof(max);
	int v = falseblnr;

	char device[32];

	/* Get a socket to routed for IPv4 */
	fd = socket(PF_ROUTE, SOCK_RAW, AF_INET);
	if (fd == -1) {
		goto label_exit;
	}

	/* Allocate a message */
	size = sizeof(struct rt_msghdr) + 16 * sizeof(struct sockaddr_in);
	message = (struct rt_msghdr*)malloc(size);
	if (! message) {
		goto label_exit;
	}
	memset(message, 0, size);
	addrs = (struct sockaddr_in*)(message + 1);

	/* Fill in the request */
	message->rtm_msglen    = size;
	message->rtm_version   = RTM_VERSION;
	message->rtm_type      = RTM_GET;
	message->rtm_addrs
		= RTA_DST | RTA_GATEWAY | RTA_NETMASK | RTA_IFP | RTA_IFA;
	addrs->sin_len         = sizeof(struct sockaddr_in);
	addrs->sin_family      = AF_INET;
	addrs->sin_addr.s_addr = 0; /* 0.0.0.0 is default route */

	/* Send the message to the kernel */
	io_count = write(fd, message, size);
	if (io_count < 0) {
		goto label_exit;
	}

	/* Read the result from the kernel */
	io_count = read(fd, message, size);
	if (io_count < 0) {
		goto label_exit;
	}

	/*
		Close the route socket. fd is shared with the BPF device
		opened further down, so clear it as well: on any failure
		below we must not leave a closed descriptor number behind
		for LT_TransmitPacket to write into, since by then the
		number may have been recycled by some other open file.
	*/
	close(fd);
	fd = -1;

	/* Get pointer to the result then parse it */
	sa = (struct sockaddr*)
		((unsigned long int)message + sizeof(struct rt_msghdr));
	get_sockaddrs(message->rtm_addrs, sa, sa_list);

	/* Must have a LINK (Ethernet) */
	if ((! sa_list[RTAX_IFP])
		|| (sa_list[RTAX_IFP]->sa_family != AF_LINK))
	{
		goto label_exit;
	}

	link = (struct sockaddr_dl*)sa_list[RTAX_IFP];
	namelen = link->sdl_nlen;

	/*
		sdl_nlen and sdl_alen are bytes, so they can describe more
		than device holds, and more than the 6 byte address copied
		out below. Check both before believing either.
	*/
	if ((namelen >= (int)sizeof(device)) || (link->sdl_alen < 6)) {
		goto label_exit;
	}

	strncpy(device, &link->sdl_data[0], namelen);
	device[namelen] = 0;
	memcpy(device_address, &link->sdl_data[namelen], 6);
	memcpy(&(tx_buffer[6]), &link->sdl_data[namelen], 6);

	/* debug.bpf_maxdevices is a plain int (see bpf(4)) */
	result = sysctlbyname("debug.bpf_maxdevices", &max, &len, NULL, 0);
	if ((result == -1) || (len != sizeof(max)) || (max <= 0)) {
		goto label_exit;
	}

	for (loop = 0; loop < max; loop++) {
		(void) snprintf(filename, sizeof(filename), "/dev/bpf%d", loop);
		fd = open(filename, O_RDWR | O_NONBLOCK | O_EXLOCK);
		if (fd >= 0) {
			/* sprintf(buffer, "using %s\n", filename); */
			break;
		}
	}

	if (fd < 0) {
		goto label_exit;
	}

	memset(&ifreq, 0, sizeof(struct ifreq));
	strncpy(ifreq.ifr_name, device, IFNAMSIZ);
	result = ioctl(fd, BIOCSETIF, &ifreq);
	if (result) {
		goto label_exit;
	}

	result = ioctl(fd, BIOCGBLEN, &device_buffer_size);
	if (result) {
		goto label_exit;
	}

	result = ioctl(fd, BIOCPROMISC, &enable);
	if (result) {
		goto label_exit;
	}

	result = ioctl(fd, BIOCSSEESENT, &enable);
	if (result) {
		goto label_exit;
	}

	result = ioctl(fd, BIOCSHDRCMPLT, &enable);
	if (result) {
		goto label_exit;
	}

	result = ioctl(fd, BIOCIMMEDIATE, &enable);
	if (result) {
		goto label_exit;
	}

	/*
		The record walk in LT_ReceivePacket assumes the bpf_hdr
		layout these headers describe, so refuse a kernel BPF whose
		version is incompatible, as bpf(4) recommends.
	*/
	result = ioctl(fd, BIOCVERSION, &bpf_version);
	if (result
		|| (bpf_version.bv_major != BPF_MAJOR_VERSION)
		|| (bpf_version.bv_minor < BPF_MINOR_VERSION))
	{
		goto label_exit;
	}

	bpf_program.bf_len = 4;
	bpf_program.bf_insns = insns;

	result = ioctl(fd, BIOCSETF, &bpf_program);
	if (result) {
		goto label_exit;
	}

	v = trueblnr;

label_exit:
	if (NULL != message) {
		free(message);
	}
	if ((! v) && (fd >= 0)) {
		/*
			Leave no usable descriptor behind on failure, so that
			the transmit and receive paths become harmless no-ops
			instead of acting on an unconfigured or unrelated file.
		*/
		close(fd);
		fd = -1;
	}

	return v;
}

LOCALVAR unsigned char *MyRxBuffer = NULL;

/*
	External function needed at startup to initialize the LocalTalk
	functionality.
*/
LOCALFUNC int InitLocalTalk(void)
{
	ui5r stamp;

	/*
		Perform a lot of stuff to get access to the Ethernet.
		Failing is not fatal - opening /dev/bpf* generally needs
		privileges we may not have - so carry on with LocalTalk
		inert rather than refusing to start the emulator at all.
	*/
	if (! get_ethernet()) {
#if dbglog_HAVE
		dbglog_writeln("get_ethernet failed, LocalTalk disabled");
#endif
	}

	LT_PickStampNodeHint();

	/*
		Save the process id in the transmit buffer as it may be used
		later to uniquely identify the sender to identify collisions
		in dynamic llap node address assignment.
		tx_buffer[14] is not 4 byte aligned, so storing through a
		uint32_t pointer would be undefined behaviour; copy bytes.
	*/
	stamp = htonl(LT_MyStamp);
	memcpy(&tx_buffer[14], &stamp, 4);

	LT_TxBuffer = (ui3p)&tx_buffer[20];

	if (0 != device_buffer_size) {
		MyRxBuffer = malloc(device_buffer_size);
		if (NULL == MyRxBuffer) {
			return falseblnr;
		}
	}

	/* Initialized properly */
	return trueblnr;
}

LOCALPROC UnInitLocalTalk(void)
{
	if (-1 != fd) {
		close(fd);
		fd = -1;
	}
	if (NULL != MyRxBuffer) {
		free(MyRxBuffer);
		MyRxBuffer = NULL;
	}
}

GLOBALOSGLUPROC LT_TransmitPacket(void)
{
	ssize_t count;
	uint16_t llap_length;

	/*
		If get_ethernet failed there is no BPF device; LocalTalk is
		inert and the frame is simply lost, as on an unplugged
		network.
	*/
	if (fd < 0) {
		return;
	}

	/*
		SCC_PutWR8 already stops LT_TxBuffSz at LT_TxBfMxSz, but
		tx_buffer has room for exactly that many bytes after the
		header, so check here too rather than trust a distant caller
		with a read past the end of the buffer.
	*/
	if (LT_TxBuffSz > LT_TxBfMxSz) {
		return;
	}

	/*
		Write the length in the packet.  This is needed because
		Ethernet has a minimum 60 bytes length, which the MAC chip
		will enforce on TX.  Without the size, a simple 3 byte LLAP
		packet would look like a (60 - 14 =) 46 byte LLAP packet.
		tx_buffer[18] is not 2 byte aligned, so copy bytes.
	*/
	llap_length = htons(LT_TxBuffSz);
	memcpy(&tx_buffer[18], &llap_length, 2);

	/* Send the packet to Ethernet */
	count = write(fd, tx_buffer, 20 + LT_TxBuffSz);
	if (count < 0) {
		/*
			A lost frame is normal LocalTalk behaviour, and the
			protocols above LLAP retransmit, so just note it.
		*/
#if BPF_dolog
		dbglog_writeCStr("BPF write fails, errno ");
		dbglog_writeNum(errno);
		dbglog_writeReturn();
#endif
	}
}

LOCALVAR unsigned char* NextPacket = NULL;
LOCALVAR unsigned char* EndPackets = NULL;

LOCALPROC LocalTalkTick0(void)
{
	/* Get a single buffer worth of packets from BPF */
	unsigned char* device_buffer = MyRxBuffer;
	ssize_t bytes;

	if ((fd < 0) || (NULL == device_buffer)) {
		return;
	}

	bytes = read(fd, device_buffer, device_buffer_size);
	if (bytes > 0) {
		/* Maybe multiple packets in this buffer */
#if 0
		dbglog_writeln("SCC founds packets from BPF");
#endif
		NextPacket = device_buffer;
		EndPackets = device_buffer + bytes;
	}
}

GLOBALOSGLUPROC LT_ReceivePacket(void)
{
label_retry:
	if (NextPacket == NULL) {
		LocalTalkTick0();
		if (NextPacket != NULL) {
			goto label_retry;
		}
	} else if (NextPacket >= EndPackets) {
#if 0
		dbglog_writeln("SCC finished set of packets from BPF");
#endif
		NextPacket = NULL;
		goto label_retry;
	} else {
		/*
			Everything below is read from a buffer the kernel filled
			with frames from the network, so each record's lengths
			are checked against the bytes actually read before they
			are believed. A record that does not fit means the
			buffer is not what we think it is, so drop the rest.
		*/
		unsigned char* packet = NextPacket;
		size_t remaining = EndPackets - NextPacket;
		struct bpf_hdr header;
		size_t advance;
		unsigned char *buff;
		unsigned char* start;
		int payload_length;
		int llap_length;
		uint16_t length_field;
		uint32_t stamp_field;

		if (remaining < sizeof(header)) {
			NextPacket = NULL;
			goto label_retry;
		}
		memcpy(&header, packet, sizeof(header));

		if ((header.bh_hdrlen < sizeof(header))
			|| (header.bh_hdrlen > remaining)
			|| (header.bh_caplen > remaining - header.bh_hdrlen))
		{
			NextPacket = NULL;
			goto label_retry;
		}

		/*
			Advance to next packet in buffer. The last record need
			not be padded out to the alignment, so never step past
			EndPackets (forming such a pointer is itself undefined).
		*/
		advance = BPF_WORDALIGN(header.bh_hdrlen + header.bh_caplen);
		if (advance > remaining) {
			advance = remaining;
		}
		NextPacket += advance;

		/* Get clean references to data */
		buff = packet + header.bh_hdrlen;
		start = buff + 20;
		/*
			The payload begins 20 bytes into the frame: 14 bytes of
			Ethernet header, then the 4 byte stamp and the 2 byte
			length written by LT_TransmitPacket. So only
			bh_caplen - 20 bytes of payload were actually captured,
			and a frame too short to hold the length field has none.
		*/
		payload_length = (int)header.bh_caplen - 20;

		if (payload_length < 0) {
			goto label_retry;
		}

		/*
			buff + 14 and buff + 18 are not suitably aligned for
			direct uint32_t / uint16_t loads, so copy bytes.
		*/
		memcpy(&length_field, buff + 18, 2);
		llap_length = ntohs(length_field);

		/*
			The SCC reads the 3 byte LLAP header (destination,
			source, type) in LT_RxBuffer[0..2] unconditionally, so a
			shorter frame would expose bytes we did not receive.
		*/
		if ((llap_length >= 3) && (llap_length <= payload_length)) {
			memcpy(&stamp_field, buff + 14, 4);

			/* Start the receiver */
			CertainlyNotMyPacket = (LT_MyStamp != ntohl(stamp_field));

#if BPF_dolog
			dbglog_writeCStr("LT_MyStamp: ");
			dbglog_writeNum(LT_MyStamp);
			dbglog_writeCStr(", received stamp: ");
			dbglog_writeNum(ntohl(stamp_field));
			dbglog_writeCStr(", CertainlyNotMyPacket: ");
			dbglog_writeNum(CertainlyNotMyPacket);
			dbglog_writeReturn();
#endif

			LT_RxBuffer    = (ui3p)start;
			LT_RxBuffSz    = llap_length;
		} else {
			goto label_retry;
		}
	}
}

#if ! LT_MayHaveEcho
#error "LT over BPF does not implement preventing echo"
#endif
