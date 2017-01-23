module Cmdl

"""
Cmdl.dict( ARGS )
"""
function dict( args::Array{String,1}; extra::Bool=false, debug::Bool=false )
 rv=Dict()
 lastkey=""
 let args = ( !extra && (x = findfirst( x->x=="--", args))>0 ) ? args[1:x-1] : args
  st = start(args)
  while !done(args,st)
   (arg,st)=next(args,st)
   debug && info(arg)
   if (m=match( r"^-(?<k>\w)(?<v>.+)", arg)) != nothing ||
      (m=match( r"^--(?<k>[\w\-]+)\=(?<v>.+)", arg)) != nothing
        push!( get!(rv, m[:k], []), m[:v] )
        lastkey=m[:k]
   elseif (m=match( r"^-(?<k>\w)$", arg)) != nothing ||
          (m=match( r"^--(?<k>[\w\-]+)$", arg)) != nothing
              get!(rv, m[:k],[])
              lastkey=m[:k] 
   elseif !isempty( (vv=split( arg, r"\s+");) )
        append!( get!(rv, lastkey, []), vv )
   end 
  end
 end
 rv
end


"""
tu = Cmdl.dict( ARGS ) |> 
 opt( "file", mustbe=isfile, msg="--file must be a real file", musthave=true ) |>
 opt( "o", to=Int, mustbe=o->0<o<3) |> 
 opt( "fi", musthave=1) |> 
 opt( "asd",to=Int, musthave=2) |>
 opt( "a", to=Int) |> 
 opt( "new", to=Int, mustbe=x->x>5) |>
 unexpected( warning=true)

Boolean options: 

julia -e'1' -q -i --  --opt1 --opt2=true --opt3=false

julia> using Cmdl

julia> opts = Cmdl.dict( ARGS ) |>
        opt("opt1",to=Bool ) |>
        opt("opt2",to=Bool) |>
        opt("opt3",to=Bool) |>
        unexpected(warning=true)
Dict{Any,Any} with 3 entries:
  "opt3" => false
  "opt1" => true
  "opt2" => true 
"""
function opt( n::AbstractString; to::Type=AbstractString, mustbe::Function=x->true, msg::AbstractString="$n !",
    musthave::Union{Bool,Int}=false )
 function a( tu::Tuple )
  cmddict::Dict = tu[1] 
  found::Dict = (length(tu)>1) ? tu[2] : Dict()
  nvals = Base.get( cmddict, n, [] )
  if to==Bool
    v = false
    if haskey( cmddict, n)
      if length(nvals)>1 error("Option \"$n\" may have only one value, which is one of 'true','false' or nothing")
      elseif length(nvals)==1
        v = nvals[1]=="true"?true :
            nvals[1]=="false"?false:
            error("Option \"$n\" may have only 'true'|'false'")
      else # has key, but values array is isempty
        v = true
      end
    end
    get!( found, n, v)
  else
    vv=[]
    if typeof(musthave)<:Bool 
      musthave && isempty(nvals) && error("Command line option \"$n\" must be defined: $msg")
    else
      musthave!=length(nvals) && error("Command line option \"$n\" must have $musthave value(s)")
    end
    for s in nvals
     v = (typeof(s)<:to) ? s : parse(to, s) 
     !mustbe(v) && error( "$msg : $n $v")
     push!(vv,v)
    end
    append!( get!( found, n, []), vv)
  end
  return (cmddict, found)
 end

 a( cmddict::Dict) = a( (cmddict,Dict()) )
end
export opt

unexpected(;warning=false) = x->unexpected(x,warning=warning)

function unexpected(tu; warning=false)
 cmddict, needdict = tu
 for opt in keys( cmddict )
  !haskey( needdict, opt) && "unexpected option \"$opt\" in command line args"|> e->warning?warn(e):error(e)
 end
 needdict
end
export unexpected

#=
function args( wants...; extra=true )
 argd = dict(ARGS, extra=extra)
 rv = Dict()
 for w in wants
  if typeof(w)<:AbstractString
   get( argd, w, "")
  end
 end # не доделано
end
=#

#=
immutable WantOpt
 wantname::AbstractString
 wanttypestr::AbstractString
 wanttype::Type
 converting::Function
 re::Regex

 function WantOpt(n,s,t,f)
    if s=="b"
    r = Regex("-{1,2}$n")
    end
    if s=="i"   
    r = Regex("-{1,2}$n.*=(\\d+)")
    end 
    if s=="f"   
    r = Regex("-{1,2}$n.*=(\\d+\\.?\\d?)")
    end 
    if s=="s"   
    r = Regex("-{1,2}$n.*=(.+)")
    end 

    new(n,s,t,f,r)
 end
end

immutable GetOpt
 w::WantOpt
 rv
 from::AbstractString
end


function wantopt(w::AbstractString)
    (n,s,t) = name_str_type(w)
    f = Base.get(str_convert,s,nothing)
    WantOpt(n::AbstractString,s::AbstractString,t::Type,f::Function)
end


function wantopt{S<:AbstractString}(w::Pair{S,Function})
    (n,s,t) = name_str_type(w[1])
    WantOpt(n,s,t,w[2])
end


function name_str_type(w::AbstractString)
    m = match(r"(?P<wantname>.+?)\=(?P<wanttype>\w)", w)
    if m!=nothing
        t = Base.get(str_type, m[:wanttype], AbstractString)::Type
        return (m[:wantname], m[:wanttype], t)
    end
 
    m = match(r"(?P<wantname>.+)", w)
    if m!=nothing
        t = Base.get(str_type, "b", AbstractString)::Type
        return (m[:wantname],"b", t)
    end
 
    ("", "", AbstractString)
end


str_type = Dict( "i"=>Int, "f"=>Float64, "b"=>Bool ) 
str_convert = Dict( 
    "i"=>s->parse(Int,s), 
    "f"=>s->parse(Float64,s),
    "b"=>s->!isempty(s),
    "s"=>s->s
)


"""
    If you want to see full return structure, use find()
    It work same as get, except, it return full structure
     for wanted key(s).
"""
function find(wants...)
 wantopts = []
 for w in wants
    push!(wantopts, wantopt(w))
 end
 rv = findopt(wantopts)
end

findopt(ww::Vector{WantOpt}, given_args::Array) = map(w->findopt(w,ARGS) , wantopts)

function findopt(w::WantOpt, given_args::Array)
    rv = []
    for arg in given_args
    m = match(w.re, arg)
    if m!=nothing
        if isempty(m.captures)
            push!(rv, GetOpt(w,true,arg))
        else
            push!(rv, GetOpt(w, m.captures[1]|>w.converting, arg))
        end        
    end
    end
    rv  
end


"""
    If you wait multiple values for the same command line key,
     f.e. your script runned as:
    
    myscript -key1=123 -key1=234 -key2=345
    
    then:

    myarray = get(\"key1=i\")::Array 

    (will empty array if not found key)
    or
    
    (arr1, arr2) = get(\"key1=i\",\"key2=i\")
"""
get() = nothing
function get(args...)
 rv = map( find(args...) ) do found_arr
      map(found_arr) do found
        found.rv
      end
 end
 l = length(rv)
 l==0 ? nothing :
 l==1 ? rv[1] :
 rv         
end

"""
    # If your script runned as: myscript --mykey1=kuku -mykey2=lala
    # then you can get (string or nothing):

    val1 = first(\"mykey1=s\")::Union{AbstractString,Void}
    
    # two values at a time:

    (val1, val2) = first(\"mykey1=s\",\"mykey2=s\")
    
    first(),get(),find() arguments - wanted key descriptions
    in format \"keyname\" or \"keyname=T\", 
    where T may be one of:
        s - AbstractString
        i - Int
        f - Float64
        b - Bool (default, if \"=T\" not present in format)
    
    Each wanted commandline argument will converted into required type.
        
    first() will raise error if got more then one value for ther one key.
    For multiple key values use get().
    
"""
function first(args...)
 rv = []
 for arg in args
    rv_arr = find(arg)[1]
    l = length(rv_arr)
    topush = l == 0 ? nothing :
         l == 1 ? Base.first(rv_arr).rv :
             begin 
                error("""
Excpected single command line argument via first(\"$arg\").
Found $l matched arguments: $(join(map(a->a.from,rv_arr),",")). 
        """)
        Base.first(rv_arr).rv
        end
    push!(rv, topush)
 end
 
 l = length(rv)
 l==0 ? nothing :
 l==1 ? rv[1] :
 rv         
end   
=#

end # module