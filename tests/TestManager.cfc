component extends = "mxunit.framework.TestCase" {

	function beforeTests() {
		try {
			variables.cacheManager = new lib.ehcache.Manager();
		} catch(Any e) {
			variables.exception = e;
		}
	}

	function afterTests() {
		variables.cacheManager.getCache("mxunitCache").flush();
//		variables.cacheManager.removeCache("mxunitCache");

		variables.cacheManager.getCache("mxunitCache100").flush();
//		variables.cacheManager.removeCache("mxunitCache100");

		variables.cacheManager.getCache("mxunitCache2").flush();
//		variables.cacheManager.removeCache("mxunitCache2");

		variables.cacheManager.getCache("mxunitCache3").flush();
//		variables.cacheManager.removeCache("mxunitCache3");

		variables.cacheManager.getCache("mxunitCache4").flush();
//		variables.cacheManager.removeCache("mxunitCache3");

		variables.cacheManager.removeCache("mxunitCache_default");
//		variables.cacheManager.removeCache("mxunitCache_override");
	}

	function test_addCache_default() {

		variables.cacheManager.addCache("mxunitCache_default");

		assertTrue(variables.cacheManager.cacheExists("mxunitCache_default"));
	}

	function test_addCache_override() {
		variables.cacheManager.addCache("mxunitCache_override", "mxunitCache_default");

		assertTrue(variables.cacheManager.cacheExists("mxunitCache_override"));
	}

	function test_createFromPath() {
		local.cacheManager = variables.cacheManager.createFromPath(expandPath("/lib/ehcache/tests/test.xml.cfm"));

		cachePut("element", { "meep": "bleep" }, "", "", "mxunitCache");

		assertEquals("mxunitCacheManager", local.cacheManager.getName());
		assertTrue(cacheRegionExists("mxunitCache"));
	}

	function test_createFromPath_amend() {
		variables.cacheManager.createFromPath(expandPath("/lib/ehcache/tests/test.xml.cfm"));
		local.cacheManager = variables.cacheManager.createFromPath(expandPath("/lib/ehcache/tests/test2.xml.cfm"));

		cachePut("element", { "meep": "bleep" }, "", "", "mxunitCache100");

		assertEquals("mxunitCacheManager", local.cacheManager.getName());
		assertTrue(cacheRegionExists("mxunitCache"));
		assertTrue(cacheRegionExists("mxunitCache100"));
	}

	function test_createFromXML() {
		local.cacheManager = variables.cacheManager.createFromXML(
			'<ehcache name="mxunitCacheManager3">
				<defaultCache
					clearOnFlush="true"
					diskExpiryThreadIntervalSeconds="3600"
					diskPersistent="false"
					diskSpoolBufferSizeMB="30"
					eternal="false"
					maxElementsInMemory="10000"
					maxElementsOnDisk="10000000"
					memoryStoreEvictionPolicy="LRU"
					overflowToDisk="false"
					timeToIdleSeconds="86400"
					timeToLiveSeconds="86400"
					statistics="false" />
				<cache
					name="mxunitCache3"
					maxEntriesLocalHeap="10000"
					timeToIdleSeconds="3600"
					timeToLiveSeconds="3600">
				</cache>
			</ehcache>'
		);

		cachePut("element", { "meep": "bleep" }, "", "", "mxunitCache3");

		assertEquals("mxunitCacheManager3", local.cacheManager.getName());
	}

	function test_getAllManagerNames() {
		debug(variables.cacheManager.getAllManagerNames());
	}

	function test_getCache() {
		assertEquals("lib.ehcache.Cache", getMetadata(variables.cacheManager.getCache("mxunitCache")).fullName);
	}

	function test_getInstance() {
		debug(variables.cacheManager.getInstance());
	}

	function test_managerExists() {
		assertTrue(variables.cacheManager.managerExists("mxunitCacheManager"));
		assertFalse(variables.cacheManager.managerExists("flargle"));
	}

	function test_removeCache() {
		variables.cacheManager.removeCache("mxunitCache_default");
		assertFalse(variables.cacheManager.cacheExists("mxunitCache_default"));
	}

}