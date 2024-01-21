.PHONY: build tag push

build:
	docker build -t baekis1185/kasm-ubuntu-jammy-desktop:build -f ./dockerfile-kasm-core-ubuntu .

tag:
	docker tag baekis1185/kasm-ubuntu-jammy-desktop:build baekis1185/kasm-ubuntu-jammy-desktop:1.14.0
	docker tag baekis1185/kasm-ubuntu-jammy-desktop:build baekis1185/kasm-ubuntu-jammy-desktop:latest

push:
	docker push baekis1185/kasm-ubuntu-jammy-desktop:1.14.0
	docker push baekis1185/kasm-ubuntu-jammy-desktop:latest

