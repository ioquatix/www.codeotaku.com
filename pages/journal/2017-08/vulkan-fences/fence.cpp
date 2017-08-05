{
	Console::debug("Submitting command buffer to GPU...");
	
	// The vulkan device:
	auto & device = _context->device();
	
	// The command buffer we want to submit:
	auto submits = vk::SubmitInfo()
		.setCommandBufferCount(1).setPCommandBuffers(&commands);
	
	// The queue we are going to submit to:
	auto queue = device.getQueue(graphics_queue, 0);
	
	// Generate a temporary fence:
	auto fence = device.createFenceUnique({});
	
	// Submit the command buffer to the queue with the fence:
	queue.submit(1, &submits, *fence);
	
	// Loop until the fence is signalled:
	while (true) {
		// Wait for 10ms for the render to complete:
		auto result = _context->device().waitForFences(1, &*fence, true, 10000000);
		
		// Check the result - if it's successful we are done:
		if (result == vk::Result::eSuccess)
			break;
		
		// Otherwise, we took longer than 10ms to render:
		Console::warn("Wait for fence: ", vk::to_string(result));
		
		// If the result wasn't a timeout (e.g. error), we fail:
		if (result != vk::Result::eTimeout)
			throw std::runtime_error("renderer failed");
	}
}