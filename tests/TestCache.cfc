component extends = "lib.util.tests.ContainerTestCase" {

	function beforeTests() {
		variables.container = new lib.ehcache.Cache(name = "MxUnit");
	}

	function setup() {
		variables.container.clear();
	}

	function test_destroy() {
		// ehcache isn't meant to be torn down at this frequency - wait until the very end of the suite
	}

	function test_getCache() {
		debug(variables.container.getCache());

		assertEquals(300, variables.container.getCache().getCacheConfiguration().getTimeToLiveSeconds());
	}

	function test_getElement() {
		variables.container.put("MxUnit_test_getElement", { "foo": "bar", "now": now() });

		debug(variables.container.getElement("MxUnit_test_getElement"));
		debug(variables.container.getElement("MxUnit_test_getElement").getTimeToIdle());
		debug(variables.container.getElement("MxUnit_test_getElement").getTimeToLive());
	}

	function test_getElementSize() {
		local.value = getTickCount();
		variables.container.put("MxUnit_test_getElementSize", local.value);
		local.elementSize = variables.container.getElementSize("MxUnit_test_getElementSize");
		debug(local.elementSize);

		assertTrue(local.elementSize > 0);
	}

	function test_scope() {
		local.value = getTickCount();
		variables.container.put("MxUnit_test_scope", local.value);

		assertEquals(local.value, variables.container.get("MxUnit_test_scope"));
	}

	function test_zzz_destroy() {
		variables.container.put("MxUnitTest_destroy", "MxUnitTest_destroy_value");
		variables.container.destroy();
		assertTrue(variables.container.isEmpty());
	}

}