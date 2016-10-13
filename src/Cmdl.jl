module Cmdl

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

"""
    If you want to see full return structure, use find()
    It work same as get, except, it return full structure
     for wanted key(s).
"""
function find(wants...)
 str_type = Dict( "i"=>Int, "f"=>Float64, "b"=>Bool ) 
 str_convert = Dict( 
    "i"=>s->parse(Int,s), 
    "f"=>s->parse(Float64,s),
    "b"=>s->!isempty(s),
    "s"=>s->s
 )    
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


 function wantopt{S<:AbstractString}(w::Pair{S,Function})
    (n,s,t) = name_str_type(w[1])
    WantOpt(n,s,t,w[2])
 end

 function wantopt(w::AbstractString)
    (n,s,t) = name_str_type(w)
    f = Base.get(str_convert,s,nothing)
    WantOpt(n::AbstractString,s::AbstractString,t::Type,f::Function)
 end 

 
 wantopts = []
 for w in wants
    push!(wantopts, wantopt(w))
 end

 
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
 
 rv = map(w->findopt(w,ARGS) , wantopts)::Array
end

"""
    If you wait multiple values for the same command line key,
     f.e. your script runned as:
    
    myscript -key1=123 -key1=234 -key2=345
    
    then:

    myarray = get(\"key1=i\")::Array 

    (will empty array if not found key)
    or
    
    (arr1, arr2) = first(\"key1=i\",\"key2=i\")
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


end # module