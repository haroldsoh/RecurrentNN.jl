type Graph
   backprop::Array{Function,1}
   doBackprop::Bool # backprop only needed during learning. Can turn off for prediction
   Graph() = new(Array(Function,0),true)
   Graph(backPropNeeded::Bool) = new(Array(Function,0),backPropNeeded)
end

function rowpluck(g::Graph, m::NNMatrix, ix::Int)
    # pluck a row of m and return it as a column vector
    out = NNMatrix(m.d, 1)
    out.w[:,1] = m.w[ix,:]'
    # backprop function
    if g.doBackprop
        push!(g.backprop,
              function ()
                 m.dw[ix,:] += out.dw[:,1]'
              end )
    end
    return out
end

function tanh(g::Graph, m::NNMatrix)
    out = NNMatrix(m.n, m.d)
    out.w = tanh(m.w)
    # backprop function
    if g.doBackprop
        push!(g.backprop,
              function ()
                  @inbounds for j = 1:m.d, i = 1:m.n
                      m.dw[i,j] += (1. - out.w[i,j]^2) * out.dw[i,j]
                  end
              end )
    end
    return out
end

function sigmoid(g::Graph, m::NNMatrix)
    out = NNMatrix(m.n, m.d,
            [1.0 / (1.0 + exp(-m.w[i,j])) for i in 1:m.n, j in m.d],
            zeros(m.n, m.d))
    # backprop function
    if g.doBackprop
        push!(g.backprop,
              function ()
                  @inbounds for j = 1:m.d, i = 1:m.n
                      m.dw[i,j] +=  out.w[i,j] * (1. - out.w[i,j]) *  out.dw[i,j]
                  end
              end )
    end
    return out
end

function relu(g::Graph, m::NNMatrix)
    out = NNMatrix(m.n, m.d)
    @inbounds for j = 1:m.d, i = 1:m.n
        out.w[i,j] = m.w[i,j] < 0. ? 0. : m.w[i,j]
    end
    # backprop function
    if g.doBackprop
        push!(g.backprop,
          function ()
              @inbounds for j = 1:m.d, i = 1:m.n
                  m.dw[i,j] +=  m.w[i,j] < 0. ? 0 : out.dw[i,j]
              end
          end )
    end
    return out
end

function mul(g::Graph, m1::NNMatrix, m2::NNMatrix)
    out = NNMatrix(m1.n, m2.d, m1.w * m2.w, zeros(m1.n, m2.d))

    # backprop function
    if g.doBackprop
        push!(g.backprop,
            function ()
                #  m1.dw : m1n x m1d 
                # out.dw : m1n x m2d
                #   m2.w : m1d x m2d
                # m1.dw += out.dw * m2.w'

                #  m2.dw : m1d x m2d 
                # out.dw : m1n x m2d
                #   m1.w : m1n x m1d
                # mw.dw += m1.w' * out.dw
                @inbounds for i = 1:m1.n, j = 1:m2.d
                    b = out.dw[i,j]
                    for k = 1:m1.d # m1's num col
                        m1.dw[i,k] += m2.w[k,j] * b

                        m2.dw[k,j] += m1.w[i,k] * b
                    end
                end
            end )
    end
    return out
end

function add(g::Graph, m1::NNMatrix, m2::NNMatrix)
    out = NNMatrix(m1.n, m1.d, m1.w + m2.w, zeros(m1.n, m1.d))
    if g.doBackprop
        push!(g.backprop,
            function ()
                @inbounds for j in 1:m1.d, i in 1:m1.n
                  m1.dw[i,j] += out.dw[i,j]
                  m2.dw[i,j] += out.dw[i,j]
                end
            end )
    end
    return out
end

function eltmul(g::Graph, m1::NNMatrix, m2::NNMatrix) # element-wise multiplication
    out = NNMatrix(m1.n, m2.d, m1.w .* m2.w, zeros(m1.n, m2.d))
    # backprop function
    if g.doBackprop
        push!(g.backprop,
            function ()
                @inbounds for j in 1:m1.d, i in 1:m1.n
                  m1.dw[i,j] += m2.w[i,j] * out.dw[i,j]
                  m2.dw[i,j] += m1.w[i,j] * out.dw[i,j]
                end
              end )
        end
    return out
end

