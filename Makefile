.PHONY: build install run logs telemetry verify clean

build:
	swift build

install:
	./script/build_and_run.sh --install

run:
	./script/build_and_run.sh

logs:
	./script/build_and_run.sh --logs

telemetry:
	./script/build_and_run.sh --telemetry

verify:
	./script/build_and_run.sh --verify

clean:
	rm -rf .build dist
