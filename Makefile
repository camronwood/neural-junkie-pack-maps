.PHONY: verify pack-zip clean pack-smoke

verify:
	./scripts/verify-pack.sh

pack-zip:
	./scripts/build-pack-zip.sh

pack-smoke:
	./scripts/pack-smoke.sh

clean:
	rm -rf dist
