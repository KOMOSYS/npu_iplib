MODULE_NAME = $(notdir $(realpath ../))

all:
	python3 ../../../script/synthesis/run.py -f ../sim/file_list.f -s ../rtl/$(MODULE_NAME).sdc -t $(MODULE_NAME)

clean:
	rm -rf area.txt design.txt $(MODULE_NAME).v
