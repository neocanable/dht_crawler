# dht_crawler

自己用的dht网络爬虫

**原理**

个BT种子都有一个对应的infohash的值，在kademlia算法实现的DHT里面，一个BT Client
端有4个协议，find_node、get_peers、announce_peer和ping，把自己伪装成一个DHT网络里面的一个NODE，然后接受各个地域发来的get_peers和announce_peer请求。
达到收集infohash的目的，这个就是DHT网络爬虫的最最最基本的做法



链接：[P2P中DHT网络爬虫](http://codemacro.com/2013/05/19/crawl-dht/)
