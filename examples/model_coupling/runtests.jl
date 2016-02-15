import Mads
using Base.Test

workdir = Mads.getmadsdir() # get the directory where the problem is executed
if workdir == ""
	workdir = Mads.madsdir * "/../examples/model_coupling"
end

info("External coupling ...")
md = Mads.loadmadsfile(workdir * "external-yaml.mads")
# yparam, yresults = Mads.calibrate(md)
yfor = Mads.forward(md)
md = Mads.loadmadsfile(workdir * "external-jld.mads")
# jparam, jresults = Mads.calibrate(md)
jfor = Mads.forward(md)
md = Mads.loadmadsfile(workdir * "external-ascii.mads")
# aparam, aresults = Mads.calibrate(md)
afor = Mads.forward(md)
md = Mads.loadmadsfile(workdir * "external-json.mads")
# sparam, sresults = Mads.calibrate(md)
sfor = Mads.forward(md)

@test yfor == jfor
@test afor == sfor
@test yfor == afor

info("External coupling ...")
md = Mads.loadmadsfile(workdir * "internal-linearmodel.mads")
ifor = Mads.forward(md)
md = Mads.loadmadsfile(workdir * "internal-linearmodel+template.mads")
tfor = Mads.forward(md)

@test tfor = ifor
@test ifor = yfor
