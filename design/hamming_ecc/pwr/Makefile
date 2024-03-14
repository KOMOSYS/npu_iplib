PROCESS = 5nm
MODULE_NAME = $(notdir $(realpath ../))

all:
	rm -rf $(PROCESS); \
	mkdir $(PROCESS); \
	cd $(PROCESS); \
	python3 ../../../../script/power/run.py -p $(PROCESS) -t $(MODULE_NAME) -T /top/u_$(MODULE_NAME) -n ../../syn/$(PROCESS)/$(MODULE_NAME).v -s ../../syn/$(PROCESS)/$(MODULE_NAME).sdc -S ../../sim/$(MODULE_NAME).$(PROCESS).saif