# ehcache
A ColdFusion facade for more-complex Ehcache interactions

## Motivation
DonorDrive started with the version Ehcache that shipped with Adobe ColdFusion. Overtime, we had to get deeper into the Java guts of Ehcache to manage our caches. The goal of this package is create a bridge between CF's simple cache* methods, and the verbose interface that Ehcache offers natively.

## Getting Started
The `ehcache` package assumes that it will reside in a `lib` directory under the web root, or mapped in the consuming application. You *must* also use our `lib.util` package for this to work (https://github.com/DonorDrive/util). In order to leverage the `IQueryable` interface for cache searching, you must also grab our `sql` project (https://github.com/DonorDrive/sql).

If you plan to leverage replication, or distribution strategies, you must get new jars from http://www.ehcache.org or talk to the lovely folks over at Software AG. The code contained herein is Ehcache 2.8+ compatible.

**Note**: Unless your cache is backed by Big Memory, you may see less-than-optimal query performance, as elements are queried using brute-force.

### How do I use this?
Conceptually, there are 3 major entities within Ehcache: Managers, Caches, and Elements.

**Manager**: As the name implies, manages one or more Caches. Cache replication/distribution strategies are dictated at the Manager level. Sizing and eviction constraints can be imposed in terms of location (on-heap/off-heap) and raw memory size.

**Cache**: CF refers to these as "cache regions." A Cache is a collection of Elements. Searching (if configured) happens at the Cache-level. Sizing and eviction constraints can be imposed in terms of raw memory size, or number of elements.

**Element**: A value associated to a key. Elements are put into a Cache for persistence.

*tl;dr: Ehcache allows you to put Elements into a Cache. Cache behavior is dictated by the Manager that created it.*

The `ehcache` package streamlines the complexity of provisioning instances of `Manager` and subsequently the creation of `Cache`s associated to them. Furthermore, a `Cache` may be made searchable by furnishing an `IQueryable` implementation at the time of creation.

The creation of a new Manager and searchable Cache may look something like this:

```
myQuery = queryExecute("SELECT foo, bar FROM myTable");
myQoQ = new lib.sql.QueryOfQueries(myQuery);
...
// create a new manager from XML
myCacheManager = new lib.ehcache.Manager().createFromPath(path = expandPath("lib/ehcache/test.xml.cfm"));
// create a new cache
myCache = myCacheManager.addCache(name = "mxunitTestCache");
// make the cache searchable, and immediately seed it with values from an existing query
myCache.setQueryable(myQoQ).seedFromQueryable();
```

Subsequently, querying the cache would look something like:

`myResults = myCache.select().where("foo > 5").orderBy("foo ASC").execute(limit = 5);`

If you are simply instantiating against the singleton Manager, you can still leverage native CF cache methods alongside the searching functionality outlined above (https://helpx.adobe.com/coldfusion/cfml-reference/coldfusion-functions/functions-by-category/cache-functions.html).

Otherwise, the `Cache` object supports the IContainer interface outlined in the util package linked above.

For a more in-depth example, please refer to the unit tests.