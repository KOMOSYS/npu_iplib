MODULE_NAME = $(notdir $(realpath ../))

all:
	python3 ../../../script/lint/run.py -f ../sim/file_list.f -t $(MODULE_NAME)

clean:
	rm -rf *.log *.prj *$(MODULE_NAME)* *.f *.tcl novas.* verdiLog
