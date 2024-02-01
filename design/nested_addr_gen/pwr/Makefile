MODULE_NAME = $(notdir $(realpath ../))

all:
	python3 ../../../script/power/run.py -t $(MODULE_NAME) -T /top/u_$(MODULE_NAME) -n ../syn/$(MODULE_NAME).v -s ../syn/$(MODULE_NAME).sdc -S ../sim/$(MODULE_NAME).saif

clean:
	rm -rf *.pwr.txt