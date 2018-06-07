component {

	/*
		relevant javadoc:
			- http://www.ehcache.org/apidocs/2.10.4/net/sf/ehcache/Cache.html
			- http://www.ehcache.org/apidocs/2.10.4/net/sf/ehcache/CacheManager.html
	*/

	Manager function init() {
    	return this;
	}

	Cache function addCache(required string name, string copyFrom) {
		if(!getInstance().cacheExists(arguments.name)) {
			if(structKeyExists(arguments, "copyFrom")) {
				local.config = getInstance().getCache(arguments.copyFrom).getCacheConfiguration().clone();

				local.config.name(arguments.name);

				getInstance().addCacheIfAbsent(createObject("java", "net.sf.ehcache.Cache").init(local.config));
			} else {
                getInstance().addCacheIfAbsent(arguments.name);
			}
		}

		return getCache(arguments.name);
	}

	boolean function cacheExists(required string name) {
		return getInstance().cacheExists(arguments.name);
	}

	Manager function createFromPath(required string path) {
		return new Manager().setInstance(createObject("java", "net.sf.ehcache.CacheManager").newInstance(arguments.path));
	}

	Manager function createFromXML(required string xml) {
		local.is = createObject("java", "java.io.ByteArrayInputStream").init(arguments.xml.getBytes());

		return new Manager().setInstance(createObject("java", "net.sf.ehcache.CacheManager").newInstance(local.is));
	}

	array function getAllManagerNames() {
		return arrayReduce(
			createObject("java", "net.sf.ehcache.CacheManager").ALL_CACHE_MANAGERS,
			function(l, v) {
				arrayAppend(l, v.getName());

				return l;
			},
			[]
		);
	}

	Cache function getCache(required string name) {
		return new Cache(name = arguments.name, managerName = getName());
	}

	any function getInstance(string name) {
		if(structKeyExists(arguments, "name")) {
			return createObject("java", "net.sf.ehcache.CacheManager").getCacheManager(arguments.name);
		} else if(structKeyExists(variables, "cm")) {
			return variables.cm;
		}

		return createObject("java", "net.sf.ehcache.CacheManager").getInstance();
	}

	Manager function getManager(required string name) {
		return new Manager().setInstance(getInstance(arguments.name));
	}

	string function getName() {
		return getInstance().getName();
	}

	boolean function managerExists(required string name) {
		return arrayFindNoCase(getAllManagerNames(), arguments.name);
	}

	Manager function setInstance(required any cacheManager) {
		variables.cm = arguments.cacheManager;

		return this;
	}

	void function removeCache(required string name) {
		getInstance().removeCache(arguments.name);
	}

}