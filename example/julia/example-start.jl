# Copyright (C) 2019, by Bill Burdick, ZLIB licensed, https://github.com/zot/domdom

using Domdom

module App

using Main.Domdom

dir = dirname(dirname(dirname(@__FILE__)))

#useverbose(true)

verbose("dir: ", dir)

abstract type Backend end

struct SimpleBackend <: Backend
    accounts
    SimpleBackend() = new(Dict())
end

mutable struct AccountMgr
    editing
    currentid
    dialogs
    mode
    backend
    editingids
    login
    function AccountMgr()
        new(false, 0, [], :none, SimpleBackend(), Set(), nothing)
    end
end

struct Dialog
    dom
    okfunc
    cancelfunc
end

mutable struct Account
    id
    username::String
    password::String
end

# App API

function accounts(::Backend) end
function getaccount(::Backend, id::Symbol) end
function addaccount(::Backend, acct::Account) end
function changeaccount(::Backend, acct::Account) end
function deleteaccount(::Backend, id) end

# Simple Backend

accounts(backend::SimpleBackend) = backend.accounts
getaccount(backend::SimpleBackend, id::Symbol) = get(backend.accounts, id, nothing)
addaccount(backend::SimpleBackend, acct::Account) = backend.accounts[acct.id] = acct
changeccount(backend::SimpleBackend, acct::Account) = ()
deleteaccount(backend::SimpleBackend, id) = delete!(backend.accounts, id)

# GUI Code

const props = domproperties

app(dom::Dom) = app(connection(dom))
app(con::Connection) = get!(con.properties, :aqua, AccountMgr())
app(mgr::AccountMgr) = mgr

accounts(dom::Union{Dom, Connection, AccountMgr}) = accounts(app(dom).backend)
getaccount(dom::Union{Dom, Connection, AccountMgr}, id) = getaccount(dom, Symbol(id))
getaccount(dom::Union{Dom, Connection, AccountMgr}, id::Symbol) = getaccount(app(dom).backend, id)
addaccount(dom::Union{Dom, Connection, AccountMgr}, acct::Account) = addaccount(app(dom).backend, acct)
changeaccount(dom::Union{Dom, Connection, AccountMgr}, acct::Account) = changeaccount(app(dom).backend, acct)
deleteaccount(dom::Union{Dom, Connection, AccountMgr}, id) = deleteaccount(app(dom).backend, id)

headerdom(item) = DomObject(item, :header, heading = "", login = app(item).login == nothing ? nothing : app(item).login.username)

logindom(item) = DomObject(item, :login, username="", password="")

refdom(item) = refdom(connection(item), webpath(item))
refdom(con, ref) = DomObject(con, :ref, path = ref)
deref(ref::DomObject) = getpath(connection(ref), web2julia(ref.path))

function accountsdom(dom)
    items = map(accountdomf(dom), sort(collect(values(accounts(dom))), by=x->x.username))
    accts = DomArray(connection(dom), [], items)
    DomObject(dom, :accounts, accounts = accts)
end

accountdomf(dom) = acct-> accountdom(dom, acct)
accountdom(dom::Dom) = accountdom(dom, dom.acctId)
accountdom(dom::Dom, acctid::Symbol) = accountdom(dom, accounts(dom)[acctid])
function accountdom(dom, acct::Account)
    obj = DomObject(dom, :account)
    copy!(obj, acct)
end

function Base.copy!(dst::Union{DomObject, Account}, src::Union{DomObject, Account})
    dst.username = src.username
    dst.password = src.password
    fromId = isa(src, DomObject) ? src.acctId : src.id
    if isa(dst, DomObject)
        dst.acctId = fromId
    else
        dst.id = fromId
    end
    dst
end

function fixaccountdoms(acctdoms)
    accts = sort(collect(values(accounts(acctdoms))), by = a-> lowercase(a.username))
    verbose("ACCOUNTS: $(accts)")
    editingids = app(acctdoms).editingids
    i = 1
    while i <= max(length(acctdoms), length(accts))
        if length(accts) < i
            pop!(acctdoms)
        else
            if length(acctdoms) < i || acctdoms[i].acctId != accts[i].id
                acct = accts[i]
                acctdoms[i] = acct.id in editingids ? editaccount(acct) : accountdom(acctdoms, acct)
            end
            i += 1
        end
    end
    acctdoms
end

editaccount(dom::Dom) = editaccount(dom, accounts(dom)[dom.acctId])
editaccount(parent::Dom, acct::Account) = DomObject(parent, :view, namespace="edit", contents = accountdom(parent, acct))

function pushDialog(dom::Dom, ok, cancel)
    push!(app(dom).dialogs, Dialog(dom, ok, cancel))
end

function message(dom::Dom)
end

function displayview(main, mode::Symbol, views...)
    con = connection(main)
    app(main).mode = mode
    main[1] = headerdom(con)
    idx = 1
    for view in views
        idx += 1
        main[idx] = view
    end
    while length(main) > length(views) + 1
        verbose("DELETE LAST FROM: ", main)
        pop!(main)
    end
    cleanall!(main)
end

function arrayitem(dom)
    while !isa(path(dom)[end], Number)
        dom = parent(dom)
    end
    (parent(dom), path(dom)[end])
end

function closeview(dom)
    length(root(dom)) > 1 && pop!(root(dom).main)
    root(dom).main[1].heading = ""
end

function home(dom)
    top = root(dom).main
    while length(top) > 1
        pop!(top)
    end
    top[1].heading = ""
end

function exampleStartFunc(backend::Backend)
    start(dir * "/html", config = (dir, host, port)-> println("STARTING HTTP ON $host:$port, DIR $dir")) do con, events
        events.onset(:login, :name) do dom, key, arg, obj, event
            verbose("SETTING USERNAME TO $arg")
            dom.currentusername = dom.username
        end
        events.onclick(:header, :login) do dom, key, arg, obj, event
            top = root(dom).main
            displayview(top, :login, logindom(dom))
            top[1].heading = "LOGIN"
        end
        events.onclick(:header, :logout) do dom, key, arg, obj, event
            app(dom).login = nothing
            root(dom).main[1].login = nothing
        end
        events.onclick(:header, :edit) do dom, key, arg, obj, event
            app(dom).editing = true
            top = root(dom).main
            editor = editaccount(dom, app(dom).login)
            push!(app(dom).editingids, dom.acctId)
            acct = editor.contents
            displayview(top, :edit, editor)
            top[1].heading = "EDITING"
            cleanall!(top)
            verbose("MODE: $(app(top).mode)")
            props(acct).save = function(dom)
                (accts, index) = arrayitem(dom)
                verbose("Save: $(accts)\nACCOUNT: $(dom)")
                backendacct = accounts(dom)[dom.acctId]
                copy!(backendacct, dom)
                changeaccount(app(dom), backendacct)
                delete!(app(dom).editingids, dom.acctId)
                if acct.username != top[1].login
                    top[1].login = acct.username
                end
                home(dom)
            end
            props(acct).cancel = function(dom)
                (accts, index) = arrayitem(dom)
                verbose("Cancel: $(accounts)")
                accts[index] = accountdom(root(dom), dom.acctId)
                delete!(app(dom).editingids, dom.acctId)
                home(dom)
            end
        end
        events.onclick(:header, :home) do dom, key, arg, obj, event
            home(dom)
        end
        events.onclick(:header, :accounts) do dom, key, arg, obj, event
            verbose("CLICKED ACCOUNTS")
            top = root(dom).main
            # show a list of refs
            # not using a ref to the list here so that each ref can be replaced with an editor
            displayview(top, :accounts, DomObject(dom, :accounts, accounts = fixaccountdoms(DomArray(dom))))
            top[1].heading = "ACCOUNTS"
        end
        events.onclick(:login, :ok) do dom, key, arg, obj, event
            if (acct = getaccount(dom, dom.username)) != nothing
                app(dom).login = acct
                root(dom).main[1].login = acct.username
                closeview(dom)
            else
                root(dom).main[end] = DomObject(dom, :message, content = "Bad user name or password")
            end
        end
        events.onclick(:login, :cancel) do dom, key, arg, obj, event
            closeview(dom)
        end
        events.onclick(:message, :ok) do dom, key, arg, obj, event
            closeview(dom)
        end
        events.onclick(:accounts, :newaccount) do dom, key, arg, obj, event
            verbose("CLICKED ACCOUNTS")
            top = root(dom).main
            acct = DomObject(dom, :account, username="", password="")
            props(acct).mode = :new
            push!(top, DomObject(dom, :newaccount, account = acct))
            props(acct).save = function(dom)
                verbose("Save NEW ACCOUNT")
                mgr = app(dom)
                (id, acct) = newaccount(mgr, acct.username, acct.username, acct.password)
                addaccount(mgr, acct)
                fixaccountdoms(top[2].accounts)
                closeview(dom)
            end
            props(acct).cancel = function(dom)
                verbose("Cancel NEW ACCOUNT")
                closeview(dom)
            end
        end
        events.onclick(:account, :edit) do dom, key, arg, obj, event
            index = path(dom)[end]
            verbose("EDIT[$(index)]: $(path(dom)), $(dom), $(key)")
            editor = root(dom).main[2].accounts[index] = editaccount(dom)
            acct = editor.contents
            push!(app(dom).editingids, dom.acctId)
            props(acct).save = function(dom)
                (accts, index) = arrayitem(dom)
                verbose("Save: $(accts)\nACCOUNT: $(dom)")
                backendacct = accounts(dom)[dom.acctId]
                copy!(backendacct, dom)
                changeaccount(app(dom), backendacct)
                delete!(app(dom).editingids, dom.acctId)
                fixaccountdoms(accts)
           end
            props(acct).cancel = function(dom)
                (accts, index) = arrayitem(dom)
                verbose("Cancel: $(accounts)")
                accts[index] = accountdom(root(dom), dom.acctId)
                delete!(app(dom).editingids, dom.acctId)
            end
        end
        events.onclick(:account, :save) do dom, key, arg, obj, event
            props(dom).save(dom)
        end
        events.onclick(:account, :cancel) do dom, key, arg, obj, event
            props(dom).cancel(dom)
        end
        events.onclick(:account, :delete) do dom, key, arg, obj, event
            verbose("Delete: $(path(dom)), key = $(key), arg = $(arg), $(dom),\nArrayItem: $(arrayitem(dom))\nID: $(dom.acctId)")
            deleteaccount(dom, dom.acctId)
            (array, index) = arrayitem(dom)
            deleteat!(array, index)
        end
        initaccounts(con, backend)
        #global mainDom = DomObject(con, :document, contents = DomObject(con, :top, main = DomArray(con, [], DomValue[headerdom(con)])))
        global mainDom = DomObject(con, :document, contents = DomObject(con, :top, main = DomArray(con, [], [headerdom(con)])))
    end
end

function newaccount(mgr, username, password)
    acct = newaccount(mgr, mgr.currentid, username, password)
    mgr.currentid += 1
    acct.id => acct
end

newaccount(mgr, id, username, password) = newaccount(mgr, Symbol(id), username, password)
function newaccount(mgr, id::Symbol, username, password)
    id => Account(id, username, password)
end

function initaccounts(con, backend)
    mgr = app(con)
    mgr.backend = backend
    empty!(accounts(mgr))
    copy!(accounts(mgr), Dict([
        newaccount(mgr, "fred", "Fred Flintstone", "fred")
        newaccount(mgr, "herman", "Herman Munster", "herman")
        newaccount(mgr, "lilly", "Lilly Munster", "lilly")
    ]))
end

if isinteractive()
    @async exampleStartFunc(SimpleBackend())
else
    exampleStartFunc(SimpleBackend())
end

end
