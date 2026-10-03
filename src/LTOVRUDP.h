/*
	LTOVRUDP.h

	Copyright (C) 2012 Michael Fort, Paul C. Pratt, Rob Mitchelmore

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
	LocalTalk OVeR User Datagram Protocol
*/


/*
	Echo suppression relies on the random LT_MyStamp carried in every
	datagram (see stampInPacketIsMine) together with the
	CertainlyNotMyPacket logic in SCCEMDEV.c. setup/SPCNFGGL.i always
	defines LT_MayHaveEcho to 1 when LocalTalk is enabled, so the old
	getpid() plus getifaddrs() alternative was never compiled, and it
	has been dropped rather than kept as untested code.
*/
#if ! LT_MayHaveEcho
#error "LT over UDP does not implement preventing echo"
#endif


#define UDP_dolog (dbglog_HAVE && 0)

#ifndef use_winsock
#define use_winsock 0
#endif

#if use_winsock
#define my_INVALID_SOCKET INVALID_SOCKET
#define my_SOCKET SOCKET
#define my_closesocket closesocket
#define socklen_t int
#define my_ssize_t int
#else
#define my_INVALID_SOCKET (-1)
#define my_SOCKET int
#define my_closesocket close
#define my_ssize_t ssize_t
#endif

#if dbglog_HAVE
LOCALPROC dbglog_writeSockErr(char *s)
{
	dbglog_writeCStr(s);
	dbglog_writeCStr(": err ");
#if use_winsock
	dbglog_writeNum(WSAGetLastError());
#else
	dbglog_writeNum(errno);
	dbglog_writeCStr(" (");
	dbglog_writeCStr(strerror(errno));
	dbglog_writeCStr(")");
#endif
	dbglog_writeReturn();
}
#endif

/*
	Transmit buffer for localtalk data and its metadata
*/
LOCALVAR ui3b tx_buffer[4 + LT_TxBfMxSz] =
	"pppp";


/*
	Receive buffer for LocalTalk data and its metadata.

	A well formed datagram is the 4 byte stamp plus at most
	LT_TxBfMxSz bytes of LLAP frame, which is what LT_TransmitPacket
	can send (a real LLAP frame is at most 603 bytes). recvfrom
	silently truncates a datagram that does not fit and returns only
	the length it copied, without saying so. One spare byte makes
	truncation detectable: any datagram that fills the whole buffer
	was either truncated or too long to be ours, and is dropped.
*/
#define rx_max_datagram (4 + LT_TxBfMxSz)
#define rx_buffer_allocation (rx_max_datagram + 1)

LOCALVAR my_SOCKET sock_fd = my_INVALID_SOCKET;
LOCALVAR blnr udp_ok = falseblnr;

#if use_winsock
LOCALVAR blnr have_winsock = falseblnr;
#endif

LOCALPROC start_udp(void)
{
#if use_winsock
	WSADATA wsaData;
#endif
	struct sockaddr_in addr;
	struct ip_mreq mreq;
	int one = 1;
#if ! use_winsock
	int flags;
#endif

#if use_winsock
	if (0 != WSAStartup(MAKEWORD(2, 2), &wsaData)) {
#if UDP_dolog
		dbglog_writeln("WSAStartup fails");
#endif
		return;
	}
	have_winsock = trueblnr;
#endif

	if (my_INVALID_SOCKET == (sock_fd =
		socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)))
	{
#if dbglog_HAVE
		dbglog_writeSockErr("socket");
#endif
		goto label_fail;
	}

	if (0 != setsockopt(sock_fd, SOL_SOCKET, SO_REUSEADDR,
		(const void *)&one, sizeof(one)))
	{
#if dbglog_HAVE
		dbglog_writeSockErr("setsockopt SO_REUSEADDR");
#endif
		goto label_fail;
	}

#if use_SO_REUSEPORT
	if (0 != setsockopt(sock_fd, SOL_SOCKET, SO_REUSEPORT,
		(const void *)&one, sizeof(one)))
	{
#if dbglog_HAVE
		dbglog_writeSockErr("setsockopt SO_REUSEPORT");
#endif
		goto label_fail;
	}
	/*
		https://stackoverflow.com/questions/14388706/
		how-do-so-reuseaddr-and-so-reuseport-differ
			claims that SO_REUSEPORT is the same as SO_REUSEADDR for
			multicast addresses.
	*/
#endif

	/* bind it to any address it fancies */
	memset((char*)&addr, 0, sizeof(addr));
	addr.sin_family = AF_INET;
	addr.sin_addr.s_addr = INADDR_ANY;
	addr.sin_port = htons(1954);

	/* bind it */
#if ! use_winsock
	errno = 0;
#endif
	if (0 != bind(sock_fd, (struct sockaddr*)&addr, sizeof(addr))) {
#if dbglog_HAVE
		dbglog_writeSockErr("bind");
#endif
		goto label_fail;
	}

	/* whack it on a multicast group */
	mreq.imr_multiaddr.s_addr = inet_addr("239.192.76.84");
	mreq.imr_interface.s_addr = INADDR_ANY;

	if (0 != setsockopt(sock_fd, IPPROTO_IP, IP_ADD_MEMBERSHIP,
		(const void *)&mreq, sizeof(mreq)))
	{
		/*
			Without group membership no other node's datagrams reach
			us, so the socket would be transmit only. That is worse
			than inert: the guest would claim a node address without
			ever hearing the lapACK of a node already using it. So
			treat this (typically no network at launch) as failure.
		*/
#if dbglog_HAVE
		dbglog_writeSockErr("setsockopt IP_ADD_MEMBERSHIP");
#endif
		goto label_fail;
	}

	/*
		LT_ReceivePacket is polled from the emulation thread, so a
		blocking socket would stall the whole emulator until a
		datagram arrived. Failing to make it non-blocking is fatal.
	*/
#if use_winsock
	{
		u_long iMode = 1;

		if (NO_ERROR != ioctlsocket(sock_fd, FIONBIO, &iMode)) {
#if dbglog_HAVE
			dbglog_writeSockErr("ioctlsocket FIONBIO");
#endif
			goto label_fail;
		}
	}
#else
	if ((-1 == (flags = fcntl(sock_fd, F_GETFL, 0)))
		|| (-1 == fcntl(sock_fd, F_SETFL, flags | O_NONBLOCK)))
	{
#if dbglog_HAVE
		dbglog_writeSockErr("fcntl O_NONBLOCK");
#endif
		goto label_fail;
	}
#endif

	udp_ok = trueblnr;
	return;

label_fail:
	/*
		Leave no half configured socket behind: with udp_ok false
		nothing would ever use or close it, and transmit and receive
		must see a consistent "LocalTalk inert" state.
	*/
	if (my_INVALID_SOCKET != sock_fd) {
		(void) my_closesocket(sock_fd);
		sock_fd = my_INVALID_SOCKET;
	}
#if dbglog_HAVE
	dbglog_writeln("start_udp failed, LocalTalk disabled");
#endif
}

LOCALVAR unsigned char *MyRxBuffer = NULL;
LOCALVAR struct sockaddr_in MyRxAddress;

/*
	External function needed at startup to initialize the LocalTalk
	functionality.
*/
LOCALFUNC blnr InitLocalTalk(void)
{
	LT_PickStampNodeHint();

	LT_TxBuffer = &tx_buffer[4];

	MyRxBuffer = malloc(rx_buffer_allocation);
	if (NULL == MyRxBuffer) {
		return falseblnr;
	}

	/* Set up UDP socket */
	start_udp();

	/* Initialized properly */
	return trueblnr;
}

LOCALPROC UnInitLocalTalk(void)
{
	if (my_INVALID_SOCKET != sock_fd) {
		if (0 != my_closesocket(sock_fd)) {
#if UDP_dolog
			dbglog_writeSockErr("my_closesocket sock_fd");
#endif
		}
		sock_fd = my_INVALID_SOCKET;
	}
	udp_ok = falseblnr;

#if use_winsock
	if (have_winsock) {
		if (0 != WSACleanup()) {
#if UDP_dolog
			dbglog_writeSockErr("WSACleanup");
#endif
		}
	}
#endif

	if (NULL != MyRxBuffer) {
		free(MyRxBuffer);
		MyRxBuffer = NULL;
	}
}

LOCALPROC embedMyStamp(void)
{
	/*
		embeds LT_MyStamp in network byte order in the start of the
		Tx buffer, so that receivers (including ourselves, since
		multicast loops back) can tell whether a datagram may be
		an echo of one we sent.
	*/
	int i;
	ui5r v = LT_MyStamp;

	for (i = 0; i < 4; i++) {
		tx_buffer[i] = (v >> (3 - i)*8) & 0xff;
	}
}

GLOBALOSGLUPROC LT_TransmitPacket(void)
{
	my_ssize_t bytes;
	struct sockaddr_in dest;

	/*
		If start_udp failed there is no socket; LocalTalk is inert
		and the frame is simply lost, as on an unplugged network.
	*/
	if (! udp_ok) {
		return;
	}

	/*
		SCC_PutWR8 already stops LT_TxBuffSz at LT_TxBfMxSz, but
		tx_buffer has room for exactly that many bytes after the
		stamp, so check here too rather than trust a distant caller
		with a read past the end of the buffer.
	*/
	if (LT_TxBuffSz > LT_TxBfMxSz) {
#if UDP_dolog
		dbglog_writeln("LT_TxBuffSz too large, not sent");
#endif
		return;
	}

	/* Write the packet to UDP */
#if UDP_dolog
	dbglog_writeln("writing to udp");
#endif
	embedMyStamp();

	memset((char*)&dest, 0, sizeof(dest));
	dest.sin_family = AF_INET;
	dest.sin_addr.s_addr = inet_addr("239.192.76.84");
	dest.sin_port = htons(1954);

	bytes = sendto(sock_fd,
		(const void *)tx_buffer, LT_TxBuffSz + 4, 0,
		(struct sockaddr*)&dest, sizeof(dest));
	if (bytes < 0) {
		/*
			A lost frame is normal LocalTalk behaviour, and the
			protocols above LLAP retransmit, so just note it.
		*/
#if UDP_dolog
		dbglog_writeSockErr("sendto");
#endif
	} else {
#if UDP_dolog
		dbglog_writeCStr("sent ");
		dbglog_writeNum(bytes);
		dbglog_writeCStr(" bytes");
		dbglog_writeReturn();
#endif
	}
}

/*
	stampInPacketIsMine returns 1 if the stamp embedded in the packet
	is our own LT_MyStamp, meaning the packet may be an echo of one we
	sent. A different stamp means it certainly came from someone else.
*/
LOCALFUNC int stampInPacketIsMine(void)
{
	int i;
	ui5r v = LT_MyStamp;

	for (i = 0; i < 4; i++) {
		if (MyRxBuffer[i] != ((v >> (3 - i)*8) & 0xff)) {
			return 0;
		}
	}

	return 1;
}

LOCALFUNC my_ssize_t GetNextPacket(void)
{
	unsigned char* device_buffer = MyRxBuffer;
	socklen_t addrlen = sizeof(MyRxAddress);
	my_ssize_t bytes;

	if ((! udp_ok) || (NULL == device_buffer)) {
		return -1;
	}

#if ! use_winsock
	errno = 0;
#endif
	bytes = recvfrom(sock_fd, (void *)device_buffer,
		rx_buffer_allocation, 0,
		(struct sockaddr*)&MyRxAddress, &addrlen);
	if (bytes < 0) {
#if use_winsock
		if (WSAEWOULDBLOCK != WSAGetLastError())
#else
		if (EAGAIN != errno)
#endif
		{
#if UDP_dolog
			dbglog_writeCStr("ret");
			dbglog_writeNum(bytes);
			dbglog_writeCStr(", bufsize ");
			dbglog_writeNum(rx_buffer_allocation);
#if ! use_winsock
			dbglog_writeCStr(", errno = ");
			dbglog_writeCStr(strerror(errno));
#endif
			dbglog_writeReturn();
#endif
		}
	} else {
#if UDP_dolog
		dbglog_writeCStr("got ");
		dbglog_writeNum(bytes);
		dbglog_writeCStr(", bufsize ");
		dbglog_writeNum(rx_buffer_allocation);
		dbglog_writeReturn();
#endif
	}
	return bytes;
}

GLOBALOSGLUPROC LT_ReceivePacket(void)
{
	my_ssize_t bytes;

	bytes = GetNextPacket();
	/*
		The datagram comes from the network, so its size is untrusted.
		It must hold the 4 byte stamp and at least the 3 byte LLAP
		header (destination, source, type) that the SCC reads
		unconditionally. Anything shorter would make bytes - 4 wrap
		LT_RxBuffSz, which is unsigned, to about 4 GiB.
		A datagram filling the whole buffer may have been truncated
		(see rx_buffer_allocation), so it is dropped rather than
		handed on as if it were a complete frame.

		LT_RxBuffSz is exactly the number of bytes recvfrom stored
		after the stamp, and the SCC never reads LT_RxBuffer past
		LT_RxBuffSz (it supplies the CRC bytes as zeros), so no byte
		beyond the received datagram reaches the guest.
	*/
	if ((bytes >= 4 + 3) && (bytes <= rx_max_datagram)) {
		CertainlyNotMyPacket = ! stampInPacketIsMine();

		{
#if UDP_dolog
			dbglog_writeCStr("passing ");
			dbglog_writeNum((ui5r)(bytes - 4));
			dbglog_writeCStr(" bytes to receiver");
			dbglog_writeReturn();
#endif
			LT_RxBuffer = MyRxBuffer + 4;
			LT_RxBuffSz = (ui5r)(bytes - 4);
		}
	}
}
