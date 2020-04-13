static int
rsock_socket0(int domain, int type, int proto)
{
#ifdef SOCK_CLOEXEC
	type |= SOCK_CLOEXEC;
#endif

#ifdef SOCK_NONBLOCK
	type |= SOCK_NONBLOCK;
#endif

	int result = socket(domain, type, proto);

	if (result == -1)
		return -1;

	rb_fd_fix_cloexec(result);

#ifndef SOCK_NONBLOCK
	rsock_make_fd_nonblock(result);
#endif

	return result;
}