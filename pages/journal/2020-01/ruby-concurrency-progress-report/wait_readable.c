int rb_io_wait_readable(int f)
{
	VALUE scheduler = rb_current_thread_scheduler();
	if (scheduler != Qnil) {
		VALUE result = rb_funcall(scheduler, rb_intern("wait_readable"), 1, INT2NUM(f));
		return RTEST(result);
	}
	
	/* ... Normal implementation... */
}