int rb_io_wait_readable(int f)
{
	VALUE selector = rb_current_thread_selector();
	if (selector != Qnil) {
		VALUE result = rb_funcall(selector, rb_intern("wait_readable"), 1, INT2NUM(f));
		return RTEST(result);
	}
	
	/* existing implementation ... */
}