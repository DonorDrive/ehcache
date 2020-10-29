component accessors = "true" implements = "lib.util.IContainer" {

	property name = "timeToIdleSeconds" type = "numeric";
	property name = "timeToLiveSeconds" type = "numeric";

	Cache function init(required string name, string managerName) {
		variables.name = arguments.name;

		if(structKeyExists(arguments, "managerName")) {
			// the named CacheManager
			variables.cacheManager = createObject("java", "net.sf.ehcache.CacheManager").getCacheManager(arguments.managerName);
		} else {
			// the default/singleton CacheManager
			variables.cacheManager = createObject("java", "net.sf.ehcache.CacheManager").getInstance();
		}

		// for anything more verbose, consider initializing the region prior to creating container
		if(variables.cacheManager.cacheExists(arguments.name)) {
			variables.cache = variables.cacheManager.getEhcache(javaCast("string", arguments.name));
		} else {
			variables.cache = variables.cacheManager.addCacheIfAbsent(javaCast("string", arguments.name));
		}

		return this;
	}

	void function clear() {
		variables.cache.removeAll();
	}

	boolean function containsKey(required string key) {
		return variables.cache.isKeyInCache(getKey(arguments.key));
	}

	void function destroy() {
		variables.cacheManager.removeCache(variables.name);
	}

	any function get(required string key) {
		local.element = getElement(arguments.key);

		if(!isNull(local.element)) {
			return local.element.getObjectValue();
		}
	}

	any function getElement(required string key) {
		return variables.cache.get(getKey(arguments.key));
	}

	numeric function getElementSize(required string key) {
		local.element = variables.cache.get(getKey(arguments.key));

		if(!isNull(local.element)) {
			return local.element.getSerializedSize();
		}

		return 0;
	}

	any function getCache() {
		return variables.cache;
	}

	any function getCacheManager() {
		return variables.cacheManager;
	}

	private string function getKey(required string key) {
		return lCase(arguments.key);
	}

	string function getName() {
		return variables.name;
	}

	boolean function isEmpty() {
		return variables.cacheManager.cacheExists(variables.name) ? variables.cache.getKeysWithExpiryCheck().size() == 0 : true;
	}

	string function keyList() {
		return listSort(arrayToList(variables.cache.getKeysWithExpiryCheck()), "textnocase");
	}

	void function put(required string key, required any value) {
		if(!structKeyExists(arguments, "timeToIdleSeconds")) {
			if(structKeyExists(variables, "timeToIdleSeconds")) {
				arguments.timeToIdleSeconds = variables.timeToIdleSeconds;
			} else {
				arguments.timeToIdleSeconds = variables.cache.getCacheConfiguration().getTimeToIdleSeconds();
			}
		}

		if(!structKeyExists(arguments, "timeToLiveSeconds")) {
			if(structKeyExists(variables, "timeToLiveSeconds")) {
				arguments.timeToLiveSeconds = variables.timeToLiveSeconds;
			} else {
				arguments.timeToLiveSeconds = variables.cache.getCacheConfiguration().getTimeToLiveSeconds();
			}
		}

		variables.cache.put(
			createObject("java", "net.sf.ehcache.Element")
				.init(
					getKey(arguments.key),
					arguments.value,
					javaCast("int", arguments.timeToIdleSeconds),
					javaCast("int", arguments.timeToLiveSeconds)
				)
			);
	}

	void function putAll(required struct values, boolean clear = false, boolean overwrite = false) {
		if(arguments.clear) {
			this.clear();
		}

		for(local.key in arguments.values) {
			if(!containsKey(local.key) || arguments.overwrite) {
				put(local.key, arguments.values[local.key]);
			}
		}
	}

	void function remove(required string key) {
		variables.cache.remove(getKey(arguments.key));
	}

	struct function values() {
		local.return = {};

		for(local.key in keyList()) {
			local.return[local.key] = get(local.key);
		}

		return local.return;
	}

}