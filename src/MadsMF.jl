"Matrix factorization via Levenberg Marquardt"
function MFlm(X, nk; mads=true)
	nS = size(X)[1]
	nP = size(X)[2]
	W_size = nS * nk
	W_logtransformed = trues(nS * nk)
	W_lowerbounds = ones(nS * nk) * 1e-15
	W_upperbounds = ones(nS * nk) * 10
	W_init = ones(nS * nk) * 0.5
	H_size = nP * nk
	H_logtransformed = trues(nP * nk)
	H_lowerbounds = ones(nP * nk) * 1e-15
	H_upperbounds = ones(nP * nk) * 10
	H_init = ones(nP * nk)
	nParam = W_size + H_size
	nObs = nP * nS
	x = [W_init; H_init]
	logtransformed = [W_logtransformed; H_logtransformed]
	lowerbounds = [W_lowerbounds; H_lowerbounds]
	upperbounds = [W_upperbounds; H_upperbounds]
	indexlogtransformed = find(logtransformed)
	lowerbounds[indexlogtransformed] = log10(lowerbounds[indexlogtransformed])
	upperbounds[indexlogtransformed] = log10(upperbounds[indexlogtransformed])

	function mf_reshape(x::Vector)
		W = reshape(x[1:W_size], nS, nk)
		H = reshape(x[W_size+1:end], nk, nP)
		return W, H
	end

	function mf_lm(x::Vector)
		W, H = mf_reshape(x)
		E = X - W * H
		return vec(E)
	end

	function mf_g_lm(x::Vector)
		W = reshape(x[1:W_size], nS, nk)
		H = reshape(x[W_size+1:end], nk, nP)
		Wb = zeros(nS, nk)
		Hb = zeros(nk, nP)
		J = Array(Float64, nObs, 0)
		for j = 1:nk
			for i = 1:nS
				Wb[i,j] = 1
				v = vec(-Wb * H)
				Wb[i,j] = 0
				J = [J v]
			end
		end
		for j = 1:nP
			for i = 1:nk
				Hb[i,j] = 1
				v = vec(-W * Hb)
				Hb[i,j] = 0
				J = [J v]
			end
		end
		return J
	end

	mf_lm_sin = Mads.sinetransformfunction(mf_lm, lowerbounds, upperbounds, indexlogtransformed)
	mf_g_lm_sin = Mads.sinetransformfunction(mf_g_lm, lowerbounds, upperbounds, indexlogtransformed)
	if mads
		r = Mads.levenberg_marquardt(mf_lm_sin, mf_g_lm_sin, Mads.asinetransform(x, lowerbounds, upperbounds, indexlogtransformed), maxEval=10000, maxIter=10000, tolX=1e-6, tolG=1e-12)
	else
		r = Optim.levenberg_marquardt(mf_lm_sin, mf_g_lm_sin, Mads.asinetransform(x, lowerbounds, upperbounds, indexlogtransformed), maxIter=10000)
	end
	# println("OF = $(r.f_minimum)")
	x_final = Mads.sinetransform(r.minimum, lowerbounds, upperbounds, indexlogtransformed)
	W, H = mf_reshape(x_final)
	return W, H, r.f_minimum
end