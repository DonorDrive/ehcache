<ehcache name="mxunitCacheManager" maxBytesLocalHeap="100M">
	<defaultCache
		clearOnFlush="true"
		overflowToDisk="false"
		statistics="false">
		<searchable allowDynamicIndexing="true" keys="true" values="false" />
	</defaultCache>
	<cache
		name="mxunitCache"
		timeToIdleSeconds="3600"
		timeToLiveSeconds="3600">
		<searchable allowDynamicIndexing="true" keys="true" values="false" />
	</cache>
</ehcache>