"""
Execute amanzi external groundwater flow and transport simulator 

Arguments:

- `filename` : amanzi input file name
- `nproc` : number of processor to be used by amanzi
- `quiet` : : suppress output [default `true`]
- `observation_filename` : amanzi observation filename [default "observations.out"]
- `setup` : bash script to setup amanzi environmental variables
- `amanzi_exe` : full path to the location of the amanzi executable

"""
function amanzi(filename::String, nproc::Int=nprocs_per_task, quiet::Bool=true, observation_filename::String="observations.out", setup::String="source-amanzi-setup"; amanzi_exe::String="")
	if quiet
		quiet_string = "&> /dev/null"
	else
		quiet_string = ""
	end
	if amanzi_exe == ""
		if nproc > 1
			runcmd(`bash -l -c "source $setup; rm -f $observation_filename; mpirun -n $nproc $$AMANZI_EXE --xml_file=$filename $quiet_string"`)
		else
			runcmd(`bash -l -c "source $setup; rm -f $observation_filename; $$AMANZI_EXE --xml_file=$filename $quiet_string"`)
		end
	else
		if nproc > 1
			runcmd(`bash -l -c "source $setup; rm -f $observation_filename; mpirun -n $nproc $amanzi_exe --xml_file=$filename $quiet_string"`)
		else
			runcmd(`bash -l -c "source $setup; rm -f $observation_filename; $amanzi_exe --xml_file=$filename $quiet_string"`)
		end
	end
end
