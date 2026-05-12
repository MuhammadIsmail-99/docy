import redis
from app.core.config import settings
import hashlib

class CacheService:
    def __init__(self):
        self.redis = redis.from_url(settings.REDIS_URL, decode_responses=True)
        self.bloom_key = "user_bloom_filter"

    def _get_hashes(self, item: str):
        # Simple implementation of multiple hashes for a Bloom filter
        # In a production app, use RedisBloom module if available
        h1 = int(hashlib.sha256(item.encode()).hexdigest(), 16) % 1000000
        h2 = int(hashlib.md5(item.encode()).hexdigest(), 16) % 1000000
        h3 = int(hashlib.sha1(item.encode()).hexdigest(), 16) % 1000000
        return [h1, h2, h3]

    def add_to_bloom(self, email: str):
        pipe = self.redis.pipeline()
        for h in self._get_hashes(email.lower().strip()):
            pipe.setbit(self.bloom_key, h, 1)
        pipe.execute()

    def check_bloom(self, email: str) -> bool:
        pipe = self.redis.pipeline()
        for h in self._get_hashes(email.lower().strip()):
            pipe.getbit(self.bloom_key, h)
        results = pipe.execute()
        return all(results)

    def set_cache(self, key: str, value: str, ex: int = 3600):
        self.redis.set(key, value, ex=ex)

    def get_cache(self, key: str):
        return self.redis.get(key)

cache_service = CacheService()
