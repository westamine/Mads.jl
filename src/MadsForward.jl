import ProgressMeter
import JLD

"""
Perform a forward run using the initial or provided values for the model parameters

- `forward(madsdata)`
- `forward(madsdata, paramdict)`
- `forward(madsdata, paramarray)`

Arguments:

- `madsdata` : MADS problem dictionary
- `paramdict` : dictionary of model parameter values
- `paramarray` : array of model parameter values

Returns:

- `obsvalues` : dictionary of model predictions
"""
function forward(madsdata::Associative; all::Bool=false)
	paramdict = Dict(zip(Mads.getparamkeys(madsdata), Mads.getparamsinit(madsdata)))
	forward(madsdata, paramdict; all=all)
end

function forward(madsdata::Associative, paramdict::Associative; all::Bool=false, checkpointfrequency::Int=0, checkpointfilename="checkpoint_forward")
	if length(paramdict) == 0
		return forward(madsdata; all=all)
	end
	if all
		madsdata_c = deepcopy(madsdata)
		if haskey(madsdata_c, "Wells")
			setwellweights!(madsdata_c, 1)
		elseif haskey(madsdata_c, "Observations")
			setobsweights!(madsdata_c, 1)
		end
		f = makemadscommandfunction(madsdata_c)
	else
		f = makemadscommandfunction(madsdata)
	end
	kk = collect(keys(paramdict))
	l = length(paramdict[kk[1]])
	for k = kk[2:end]
		l2 = length(paramdict[k])
		@assert l == l2
	end
	paraminitdict = DataStructures.OrderedDict(zip(keys(paramdict), getparamsinit(madsdata)))
	if l == 1
		p = merge(paraminitdict, paramdict)
		return f(p)
	else
		paramarray = hcat(map(i->collect(paramdict[i]), keys(paramdict))...)
		return forward(madsdata, paramarray; all=all, checkpointfrequency=checkpointfrequency, checkpointfilename=checkpointfilename)
	end
end

function forward(madsdata::Associative, paramarray::Array; all::Bool=false, checkpointfrequency::Int=0, checkpointfilename="checkpoint_forward")
	paramdict = Dict(zip(Mads.getparamkeys(madsdata), Mads.getparamsinit(madsdata)))
	if sizeof(paramarray) == 0
		return forward(madsdata; all=all)
	end
	if all
		madsdata_c = deepcopy(madsdata)
		if haskey(madsdata_c, "Wells")
			setwellweights!(madsdata_c, 1)
		elseif haskey(madsdata_c, "Observations")
			setobsweights!(madsdata_c, 1)
		end
		f = makedoublearrayfunction(madsdata_c)
		pk = Mads.getoptparamkeys(madsdata_c)
	else
		f = makedoublearrayfunction(madsdata)
		pk = Mads.getoptparamkeys(madsdata)
	end
	np = length(pk)
	s = size(paramarray)
	if length(s) > 2
		error("Incorrect array size: size(paramarray) = $(size(paramarray))")
	elseif length(s) == 2	
		mx = max(s...)
		mn = min(s...)
	else
		mx = s[1]
		mn = 1
	end
	if mn != np && mx != np
		error("Incorrect array size: size(paramarray) = $(size(paramarray))")
	end
	nr = (mn == np) ? mx : mn
	r = []
	if length(s) == 2
		if checkpointfrequency != 0
			restartdir = getrestartdir(madsdata)
			if s[2] == np
				r = RobustPmap.crpmap(i->f(vec(paramarray[i, :])), checkpointfrequency, joinpath(restartdir, checkpointfilename), 1:nr)
			else
				r = RobustPmap.crpmap(i->f(vec(paramarray[:, i])), checkpointfrequency, joinpath(restartdir, checkpointfilename), 1:nr)
			end
		else
			if s[2] == np
				r = RobustPmap.rpmap(i->f(vec(paramarray[i, :])), 1:nr)
			else
				r = RobustPmap.rpmap(i->f(vec(paramarray[:, i])), 1:nr)
			end
		end
	else
		o = f(paramarray)
		push!(r, o)
	end
	return hcat(r[:]...)'
end

"""
Perform a forward run over a 3D grid defined in `madsdata` using the initial or provided values for the model parameters

- `forwardgrid(madsdata)`  
- `forwardgrid(madsdata, paramvalues))`

Arguments:

- `madsdata` : MADS problem dictionary
- `paramvalues` : dictionary of model parameter values

Returns:

- `array3d` : 3D array with model predictions along a 3D grid
"""
function forwardgrid(madsdata::Associative)
	paramvalues = Dict(zip(Mads.getparamkeys(madsdata), Mads.getparamsinit(madsdata)))
	forwardgrid(madsdata, paramvalues)
end

function forwardgrid(madsdatain::Associative, paramvalues::Associative)
	madsdata = copy(madsdatain)
	f = Mads.makemadscommandfunction(madsdata)
	nx = madsdata["Grid"]["xcount"]
	ny = madsdata["Grid"]["ycount"]
	nz = madsdata["Grid"]["zcount"]
	xmin = madsdata["Grid"]["xmin"]
	ymin = madsdata["Grid"]["ymin"]
	zmin = madsdata["Grid"]["zmin"]
	xmax = madsdata["Grid"]["xmax"]
	ymax = madsdata["Grid"]["ymax"]
	zmax = madsdata["Grid"]["zmax"]
	time = madsdata["Grid"]["time"]
	dx = nx == 1 ? 0 : dx = ( xmax - xmin ) / ( nx - 1 )	
	dy = ny == 1 ? 0 : dy = ( ymax - ymin ) / ( ny - 1 )
	dz = nz == 1 ? 0 : dz = ( zmax - zmin ) / ( nz - 1 )
	x = xmin
	dictwells = Dict()
	for i in 1:nx
		x += dx
		y = ymin
		for j in 1:ny
			y += dy
			z = zmin
			for k in 1:nz
				z += dz
				wellname = "w_$(i)_$(j)_$(k)"
				dictwells[wellname] = Dict()
				dictwells[wellname]["x"] = x
				dictwells[wellname]["y"] = y
				dictwells[wellname]["z0"] = z
				dictwells[wellname]["z1"] = z
				dictwells[wellname]["on"] = true
				arrayobs = Array(Dict, 0)
				dictobs = Dict()
				dictobs["t"] = time
				dictobs["c"] = 0
				dictobs["weight"] = 1
				push!(arrayobs, dictobs)
				dictwells[wellname]["obs"] = arrayobs
			end
		end
	end
	madsdata["Wells"] = dictwells
	Mads.wells2observations!(madsdata)
	forward_results = f(paramvalues)
	s = Array(Float64, nx, ny, nz)
	for i in 1:nx
		for j in 1:ny
			for k in 1:nz
				obsname = "w_$(i)_$(j)_$(k)_$(time)"
				s[i, j, k] = forward_results[obsname]
			end
		end
	end
	return s
end
