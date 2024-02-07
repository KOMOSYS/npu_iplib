PROCESS = 5nm
MODULE_NAME = $(notdir $(realpath ../))

all: $(PROCESS)
	cd $(PROCESS); \
	python3 ../../../../script/synthesis/run.py -f ../../sim/file_list.f -p $(PROCESS) -s ./$(MODULE_NAME).sdc -t $(MODULE_NAME)
