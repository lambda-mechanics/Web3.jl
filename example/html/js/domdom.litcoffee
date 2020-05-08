# Domdom: a simple, dynamic HTML presentation system that supports local or client/server usage

Copyright (C) 2019, by Bill Burdick, ZLIB licensed, https://github.com/zot/domdom

Domdom uses a JSON object to implement its own Document Object Model that you can share with your local JavaScipt code or with a server. Domdom renders the JSON object in the browser using definitions you provide and it re-renders parts of the GUI when you change values in the JSON object. You can manage the model either in local JavaScript or on a server. Domdom also binds parts of the JSON object and changes it when users interact with the GUI, transmitting those changes to the local JavaScript code or to the server.

Domdom is engineered to be simple and lightweight, defined in roughly 600 lines of CoffeeScript.

# Overview

Domdom chooses a "view" for each nested object in the JSON object you provide by using the object's "type" property. Views are defined using Handlebars, displaying with the JSON object as their context. Domdom also supports namespaces for views, i.e. you can define different views on the same type for different contexts (an object could render as a form in one namespace and a list item in another namespace).

When the Javascript model (or server, if connected) changes some of Domdom's JSON objects, it automatically rerenders the views for those objects.

Domdom can bind values in its HTML views to paths in its JSON objects so that the HTML can display and/or change the values at thoses paths. When the user changes one of those values, Domdom changes the JSON object at that path and sends an event to the Javascript model (or the server, if connected).

# Views

Views are Handlebars templates that can also contain other views via the `view` Handlebar plugin and `data-path` attributes in divs and spans which each specify a *path* to property in a JSON object.

Input elements in views can also contain `data-path` attributes that specifying a
*path* to a property in the JSON object, example:

`<input type=text data-path="a.b.c">`

If an element has a non-null data-bind-keypress attribute, any keypresses that are not enter or return will be sent as "key" events to the Javascript model (or server, if connected).

An element is considered to be a button if it has a data-path property and it is either a non-input element, a button element, or a submit element. The behavior on the JSON object depends on its "value" attribute (if there is one):

* no value attribute: when you press the button, Domdom does not change the JSON object but it sends a click event to the model (see Events, below)
* the value is a boolean: it acts as a checkbox and when you press it, Domdom sets the boolean value in the JSON object and sends a "set" event (see Events, below)
* otherwise: when the input element changes (like by focusing out of a field), Domdom sets the JSON path in the object to the value property, parsed as a JSON value (see Events, below)

# Main JSON object

```
views: {NAMESPACE: {TYPE: HANDLEBARSDEF}, ...}
type: top
content: [DATA, ...]
```

    #TODO elaborate on this...
    #The main JSON object supplied to Domdom can optionally provide

# Events
The Javascript model (or the server, if you are connecting to one) recieves events for clicks and sets with the JSON path and the new value, if there is one. The model (or server) can then change the JSON model in response to trigger an update on the screen, which re-renders the parts of the model that have changed.

# Viewdefs

You define views with viewdefs and this is normally in the HTML file by putting `data-viewdef` attributes in HTML elements. the value of the `data-viewdef` element can be:

- `TYPE`, where TYPE is any string value a JSON object might have in its `type` property
- `NAMESPACE/TYPE`, where namespace is any name you choose to make a namespace and TYPE is as above

You can use a namespace with the `view` Handlebars plugin (see below).

You can also define viewdefs in the `views` property of the main JSON object.

Within a viewdef, you can template attributes in two ways see (example-server.html)[../example-server.html]'s account viewdef:

1. enclose the entire contents of the viewdef in an HTML comment
2. put the attribute templating in the value of a data-subst attribute

# The namespace type
The namespace type sets the namespace for its content object or array of objects, like this:

{"type": "namespace", "namespace": "bubba", "content": ...}

This will set the namespace to bubba for the content object or array of objects.

# The view plugin for Handlebars

The predefined `view` plugin lets you show a view on an object or array of objects and you can optionally set the namespace, like this:

{{{view `path.in.JSON.object`}}}

or

{{{view `path.in.JSON.object` `namespace-name`}}}

# Events
There are two types of events:

- set(path, value): the user changed something in the GUI that triggered a set event
- click(path, value): the user clicked a button, which can optionally include a value, depending on the view

# Controllers
If you need custom javascript code, you can use a script element. You an use `element.query()`, `element.queryAll()`, `element.closest()`, etc. to access your view. In addition, these properties will be available:

- `document.currentScript` will be the script element (as usual)
- `Domdom.currentScript` will also hold the script element
- `Domdom.activating` will be true, check this to verify that a view is actually initializing
- `Domdom.context` will be the current context object
- `Domdom.docPath` will be the current docPath (see DocPaths, below)

Also, each view will have a `data-location` attribute set to its path and a `data-namespace` attribute set to the view's namespace.

# Using Domdom

On the web side, you need to make sure the files in the js and css directories are available to your HTML file and include these elements (altered to fit your file layout, of course):

\<link rel="stylesheet" href="css/domdom.css">\</link>
\<script src="js/lib/handlebars-v4.0.5.js">\</script>
\<script src="js/domdom.js">\</script>

It's also compatible with AMD style so you can use something like require.js:

\<link rel="stylesheet" href="css/domdom.css">\</link>
\<script data-main="js/config" src="js/lib/require-2.1.18.js">\</script>

You can implement the model in local JavaScript or in a server. Domdom currently supports Julia servers.

# Connecting to a server
Put this at the bottom of the body of your web page, with the HOST and PORT of your server in it:

\<script>Domdom.connect({}, "ws://HOST:PORT")\</script>

The Julia server code supports its own version of event handlers and DocPath (see the JavaScript model documentation below)

# Using Domdom with a JavaScript model

* Create a Javascript object with
```
{type: 'document',
 views: {default: {viewdefs...},
 NAMESPACE1: {viewdefs...}},
 contents: [CONTENTS...]}
```

Views are optional in the object since they can also be in the HTML page.

- Create a context with {top: JSON, handler: HANDLER}
  - JSON is the JSON object you have created
  - HANDLER is an event handler
    - You can use the patternHandler() function to easily specify event handlers (see source for documentation).
    - Otherwise, the handler is {clickButton: (evt)=> ..., changedValue: (evt)=> ..., key: (evt)=> ...}
    - the dispatchClick, dispatchKey, and dispatchSet functions dispatch events in a high-level way, using DocPaths (see below)
## DocPaths
A DocPath is proxy that makes it easy navigate paths in the JSON object and it lets you change the JSON object and automatically trigger re-rendering for those changes. It's called DocPath because the JSON object is the "document" of the Document Object Model. PatternHandler and the three dispatch functions (dispatchClick, dispatchKey, and dispatchSet) each send a DocPath as the first argument to your provided event handler function.

Given docp is a DocPath...

- `docp.PROP` returns the value in the document at PROP if it is atomic or, if the value is an array or object, it returns a new DocPath for that location (with docp's path extended to include PROP)
- `docp[INDEX]` returns the value in the document at INDEX if it is atomic or, if the value is an array or object, it returns a new DocPath for that location (with docp's path extended to include INDEX)
- `docPathValue(docp)` returns docp's value
- `docp.PROP = VALUE` sets the value in the document and cause Domdom to re-render it
- `docPathParts(docp)` returns the "parts" of a DocPath, the Domdom object, the context, and the path array

You can use `batch(con, func)` if you need to change DocPaths outside of an event handler for "event compression". Batch eliminates re-rendering of the same object multiple times.

# History

I came up with the original concept around 2000 or 2001, as the next step in evolution for Classic Blend (a remote presentation system I first developed in 1995). The idea of the next step was that if you abstracted an entire GUI into a set of shared variables, you could use the variables to control a remote GUI from a server kind of like a [tuple space](https://en.wikipedia.org/wiki/Tuple_space) or like [SNMP](https://en.wikipedia.org/wiki/Simple_Network_Management_Protocol). Beyond this, you could reskin the GUI in dramatically different ways -- far more radically than GTK themes, for instance -- switching from a web browser to the Unreal engine, for example, where menus might be presented as shops (I actually prototyped a Quake-based front end at one point).

I've been using an earlier and quite different variation of this idea since 2006 on an extremely large project. The browser side of the presentation is fully automatic now and we don't write any JavaScript for our front ends anymore, unless we're adding new kinds of widgets.

This version of the concept, Domdom, grew out of the Leisure project (which will eventually be updated to use Domdom) and I've used variations of this JavaScript and server code in several of my personal projects.

The [Xus](https://github.com/zot/Xus) project is also related to this and it's also based on shared variables.

    define = window.define ? (n, func)-> window.Domdom = func(window.Handlebars)

    define ['handlebars'], (Handlebars)->
      {
        compile
        registerHelper
      } = Handlebars

      curId = 0
      _verbose = false

      setVerbose = (value)-> _verbose = value

      verbose = (args...)-> _verbose && console.log(args...)

      keyCode = (evt)->
        if !(evt.key.toLowerCase() in ['shift', 'control', 'alt'])
          key = evt.key
          if key.toLowerCase().startsWith 'arrow'
            key = key[5...].toLowerCase()
          if evt.shiftKey && key.length > 1 then key = "S-" + key
          if evt.ctrlKey then key = "C-" + key
          if evt.altKey || evt.metaKey then key = "M-" + key
          key

      parsingDiv = document.createElement 'div'

      query = document.querySelector.bind document

      queryAll = document.querySelectorAll.bind document

      find = (node, selector, includeSelf)->
        if includeSelf && node.matches selector
          [node].concat Array.prototype.slice.call(node.querySelectorAll selector)
        else
          node.querySelectorAll selector

      parseHtml = (str)->
        parsingDiv.innerHTML = "<div>#{str}</div>"
        dom = parsingDiv.firstChild
        parsingDiv.innerHTML = ''
        if dom.childNodes.length == 1 && dom.firstChild.nodeType == 1 then dom.firstChild else dom

      locationToString = (loc)->
        str = ""
        for coord in loc
          if str then str += " "
          str += coord
        str

      stringToLocation = (str)->
        if str == "" then return []
        (if String(Number(coord)) == coord then Number(coord) else coord) for coord in str.split ' '

      locationFor = (json, context)-> context.top.index[json.$ID$]?[1] || context.location

      resolvePath = (doc, location)->
        if typeof location == 'string'
          [j, path, parent] = doc.index[location]
          location = path
        if typeof location[0] == 'string' && location[0][0] == '@'
          first = location[0][1...]
          [j, path, parent] = doc.index[first]
          location = if location.length > 1 then [path..., location[1...]...] else path
        location

      normalizePath = (path, index)->
        if Array.isArray path then path
        else
          [ignore, path] = index[if typeof path == 'object' then path.$ID$ else path]
          path

      findIds = (parent, json, location = [], items={})->
        if Array.isArray json
          for el, i in json
            findIds json, el, [location..., i], items
        else if json != null && typeof json == 'object' && json.type?
          loc = locationToString location
          items[loc] = [json, location]
          for k, v of json
            findIds json, v, [location..., k], items
        items

      globalContext = namespace: 'default'

      replace = (oldDom, newDom)->
        # prefer mutating the old dom to replacing it
        if oldDom && oldDom.nodeName == newDom.nodeName && oldDom.childNodes.length == 0 && newDom.childNodes.length == 0
          na = new Set newDom.getAttributeNames()
          for n in oldDom.getAttributeNames()
            if !na.has(n) then oldDom.removeAttribute n
          for n from na
            nav = newDom.getAttribute n
            if nav != oldDom.getAttribute n
              oldDom.setAttribute n, nav
          oldDom
        else
          oldDom.replaceWith newDom
          newDom

      domdoms = []

      domdomBlur = (event)->
        for md in domdoms
          if event.target.nodeType == 1 && md.top.contains event.target
              md.blurring = true

      domdomFocus = (event)->
        for md in domdoms
          if md.blurring
            md.blurring = false
            md.runRefreshQueue()

      takeFocusForScript = (sel)->
        if isRefreshing Domdom.currentScript
          el = find(Domdom.currentScript.parentElement, sel)[0];
          setTimeout (()->
            console.log(document.activeElement)
            el.focus()), 1

      isRefreshing = (node)->
        if Domdom.activating && Domdom.refreshLocations
          path = node.closest('[data-location]')?.getAttribute 'data-location'
          if Domdom.refreshLocations.size == 0 then return true
          for p from Domdom.refreshLocations
            if path.startsWith p then return true

      class Domdom
        constructor: (@top)->
          if !@top then throw new Error "No top node for Domdom"
          @refreshQueue = [] # queued refresh commands that execute after the current event
          @refreshLocations = new Set()
          @specialTypes =
            document: (dom, json, context)=> @renderTop dom, json, context
          if !domdoms.length
            window.addEventListener "blur", domdomBlur, true
            window.addEventListener "focus", domdomFocus, true
          domdoms.push this

activateScripts inserts copies of the parsed script elements, which makes them execute.

        activateScripts: (el, ctx)->
          if !Domdom.activating
            Domdom.activating = true
            Domdom.context = ctx
            Domdom.docPath = docPath this, ctx, ctx.location
            try
              for script in el.querySelectorAll 'script'
                if (!script.type || script.type.toLowerCase() == 'text/javascript') && (text = script.textContent)
                  newScript = document.createElement 'script'
                  newScript.type = 'text/javascript'
                  if script.src then newScript.src = script.src
                  newScript.textContent = text
                  #keep the current script here in case the code needs access to it
                  Domdom.currentScript = newScript
                  script.parentNode.insertBefore newScript, script
                  script.parentNode.removeChild script
            finally
              Domdom.currentScript = null
              Domdom.activating = false
              Domdom.context = null

Find view for json and replace dom with the rendered view. Context contains global info like the
current namespace, etc.

        render: (dom, json, context)->
          context.views ?= {}
          newDom = @baseRender dom, json, Object.assign {location: []}, context
          @analyzeInputs newDom, context, Array.isArray json
          newDom

        baseRender: (dom, json, context)->
          context = Object.assign {}, globalContext, context
          if Array.isArray json
            newDom = dom
            for childDom, i in json
              el = document.createElement 'div'
              newDom.appendChild el
              @baseRender el, childDom, Object.assign {}, context, {location: [context.location..., i]}
            newDom
          else
            id = json.$ID$ ? dom.getAttribute('id') ? ++curId
            dom.setAttribute 'id', id
            if special = @specialTypes[json.type]
              special dom, json, context
            else @normalRender dom, json, context

        # special renderers can use this to modify how their views render
        normalRender: (dom, json, context)->
          def = @findViewdef json.type, context
          newDom = parseHtml(if def
            try
              old = globalContext
              globalContext = context
              def json, data: Object.assign {domdom: this}, {context}
            finally
              globalContext = old
          else "COULD NOT RENDER TYPE #{json.type}, NAMESPACE #{context.namespace}")
          newDom.setAttribute 'data-location', locationToString context.location
          if !newDom.getAttribute 'data-namespace'
            newDom.setAttribute 'data-namespace', context.namespace
          newDom.setAttribute 'id', json.$ID$
          if newDom.getAttribute 'data-path' then newDom.setAttribute 'data-path-full', locationToString context.location
          newDom = replace dom, newDom
          @populateInputs newDom, json, context
          @activateScripts newDom, context
          newDom

        findViewdef: (type, context)->
          if def = context.views?[context.namespace]?[type] then return def
          else if el = query "[data-viewdef='#{type}/#{context.namespace}']" then namespace = context.namespace
          else if def = context.views?.default?[type] then return def
          else if !(el = query "[data-viewdef='#{type}']") then return null
          if !context.views? then context.views = {}
          if !context.views[namespace]? then context.views[namespace] = {}
          domClone = el.cloneNode true
          domClone.removeAttribute 'data-viewdef'
          if domClone.firstChild && domClone.firstChild.nodeType == Node.COMMENT_NODE && domClone.firstChild == domClone.lastChild
            context.views[namespace][type] = compile domClone.outerHTML.replace /<!--((.|\n)*)-->/, '$1'
          else
            r1 = /data-subst=\'([^\']*)\'/
            r2 = /data-subst=\"([^\"]*)\"/
            context.views[namespace][type] = compile domClone.outerHTML.replace(r1, '$1').replace(r2, '$1')

        rerender: (json, context, thenBlock, exceptNode)->
          @refreshLocations.add(locationToString(context.location))
          @queueRefresh =>
            for oldDom in @domsForRerender json, context when !exceptNode || oldDom != exceptNode
              oldLocation = oldDom.getAttribute 'data-location'
              context = Object.assign {}, context, rerender: locationFor json, context
              if oldLocation == locationToString(locationFor(json, context)) && oldDom.getAttribute 'data-namespace' then context.namespace = oldDom.getAttribute 'data-namespace'
              newDom = if context.location.length == 1 then @renderTop oldDom, context.top, context
              else newDom = @render oldDom, json, context
              top = newDom.closest('[data-top]')
              for node in find newDom, '[data-path-full]'
                @valueChanged top, node, context
            thenBlock newDom

domsForRender(json, context) finds the doms for json or creates and inserts a blank one

        domsForRerender: (json, context)->
          if !json
            for node in queryAll("[data-location^='#{locationToString context.location}']")
              node.remove()
            return []
          if location = locationFor json, context
            loc = locationToString context.location
            targets = queryAll("[data-location^='#{loc}']")
            if targets.length == 1 then return targets
            for node in targets
              if node.getAttribute('data-location') != loc && node.parentNode.closest("[data-location^='#{loc}']")
                node.remove()
            if targets.length then return targets
            inside = false
            end = location[location.length - 1]
            if typeof end == 'number' then parent = @getPath context.top, context.top.contents, [location[0...-1]..., end - 1]
            else
              parent = @getPath context.top, context.top.contents, location[0...-1]
              inside = true
            if parentDom = query "[id='#{parent.$ID$}']"
              dom = parseHtml "<div id='#{json.$ID$}' data-location='#{locationToString location}'></div>"
              if inside then parentDom.appendChild dom
              else parentDom.after dom
            return [dom]
          return []

        renderTop: (dom, json, context)->
          {views, contents} = json
          json.index = {}
          for k, v of findIds null, contents
            if !v.$ID$ then v[0].$ID$ = ++curId
            json.index[v[0].$ID$] = v
          json.compiledViews = {}
          context.views ?= {}
          for namespace, types of views
            json.compiledViews[namespace] ?= {}
            context.views[namespace] ?= {}
            for type, def of types
              #destructively modify context's views
              context.views[namespace][type] = json.compiledViews[namespace][type] = compile(def)
          newDom = @baseRender dom, contents.main, Object.assign context, {top: json, location: ['main']}
          newDom.setAttribute 'data-top', 'true'
          newDom

        queueRefresh: (cmd)->
          @refreshQueue.push cmd
          if !@pressed && !@blurring && document.activeElement != document.body
            @runRefreshQueue()

        runRefreshQueue: ->
          if @refreshQueue.length > 0
            q = @refreshQueue
            @refreshQueue = []
            setTimeout (=>
              Domdom.refreshLocations = @refreshLocations
              active = document.activeElement
              focusPath = active && active.getAttribute 'data-path-full'
              for cmd in q
                cmd()
              @refreshLocations.clear()
              Domdom.refreshLocations = null
              if focusPath
                field = query("[data-path-full='#{focusPath}']")
                field?.focus()
                field?.select?()
            ), 5

        adjustIndex: (index, path, parent, oldJson, newJson)->
          oldIds = findIds parent, oldJson, path
          newIds = findIds parent, newJson, path
          oldKeys = new Set(Object.keys(oldIds))
          for k, v of newIds
            if !v[0].$ID$ && oldIds[k]?[0].$ID$
              v[0].$ID$ = oldIds[k][0].$ID$
            else if !v[0].$ID$
              v[0].$ID$ = ++curId
            index[v[0].$ID$] = v
            oldKeys.delete(k)
          for k from oldKeys
            delete index[oldIds[k][0].$ID$]

        analyzeInputs: (dom, context, array)->
          for node in find dom, "input, textarea, button, [data-path]", true when !array || node != dom
            do (node)=> if fullpath = node.getAttribute 'data-path-full'
              path = stringToLocation node.getAttribute 'data-path-full'
              if node.getAttribute 'data-bind-keypress'
                node.on 'keydown', (e)->
                  if !(keyCode(e) in ['C-r', 'C-J'])
                    e.preventDefault()
                    e.stopPropagation()
                    context.handler.keyPress? e.originalEvent
              if node.nodeName in ['DIV', 'SPAN'] # handle data-path in divs and spans
                if node.getAttribute 'data-replace'
                  node.innerHTML = ''
                  renderingNode = node
                else
                  node.innerHTML = '<div></div>'
                  renderingNode = node.firstChild
                path = stringToLocation node.getAttribute 'data-path-full'
                subcontext = Object.assign {}, context,
                  location: path
                  namespace: node.getAttribute 'data-namespace'
                newDom = @render renderingNode, @getPath(context.top, context.top.contents, path), subcontext
                node.removeAttribute 'data-path'
                for attr in ['style', 'class']
                  if node.getAttribute(attr) && !newDom.getAttribute(attr)
                    newDom.setAttribute(attr, node.getAttribute(attr))
              else if (node.type in ['button', 'submit']) || !(node.type in ['text', 'password'])
                # using onmousedown, onclick, path, and @pressed because
                # the view can render out from under the button if focus changes
                # which replaces the button with ta new one in the middle of a click event
                node.onmousedown = (evt)=> @pressed = path
                node.onclick = (evt)=>
                  if @pressed == path || evt.detail == 0
                    @pressed = false
                    newValue = if v = node.getAttribute 'value'
                      try
                        JSON.parse v
                      catch err
                        v
                    else if (typeof (oldValue = @getPath context.top, context.top.contents, path)) == 'boolean'
                      newValue = !oldValue
                    if newValue
                      @setValueFromUser node, evt, dom, context, path, newValue
                    else
                      context.handler.clickButton? evt
                    @runRefreshQueue()
              else
                node.onchange = (evt)=>
                  ownerPathString = evt.srcElement.closest('[data-location]').getAttribute 'data-location'
                  ownerPath = stringToLocation ownerPathString
                  @setValueFromUser node, evt, dom, context, path, node.value

        setValueFromUser: (node, evt, dom, context, path, value)->
          ownerPathString = node.closest('[data-location]').getAttribute 'data-location'
          ownerPath = stringToLocation ownerPathString
          json = @getPath context.top, context.top.contents, ownerPath
          @setPath context.top, context.top.contents, path, value
          context.handler.changedValue? evt, value

        populateInputs: (dom, json, context)->
          for node in find dom, "[data-path]", true
            location = stringToLocation node.closest('[data-location]').getAttribute 'data-location'
            path = node.getAttribute('data-path').split('.')
            fullpath = locationToString [location..., path...]
            if node.type in ['text', 'password'] then node.setAttribute 'value', @getPath context.top, json, path
            node.setAttribute 'data-path-full', fullpath
            setSome = true
            setSome

        valueChanged: (dom, source, context)->
          value = source.value
          fullpath = source.getAttribute 'data-path-full'
          json = @getPath context.top, context.top.contents, (stringToLocation fullpath)[0...-1]
          for node in find(dom, "[data-path-full='#{fullpath}']") when node != source
            node.value = value
            remove = new Set()
            for attr in node.attributes
              if attr.name.startsWith 'data-attribute-'
                setAttr = attr.name.substring('data-attribute-'.length)
                if json[attr.value]?
                  attr[setAttr] = json[attr.value]
                else if node.hasAttribute(setAttr) then remove.add(setAttr)
            for attr from remove
              node.removeAttribute attr

        getPath: (doc, json, location)->
          location = resolvePath doc, location
          for i in location
            json = json[i]
          json

        setPath: (document, json, location, value)->
          last = json
          lastI = 0
          location = resolvePath document, location
          for i, index in location
            if index + 1 < location.length #not at the end
              last = json
              lastI = i
              json = json[i]
            else # at the end
              if value?.type?
                @adjustIndex document.index, location[0..index], json, json[i], value
              else
                newJson = Object.assign {}, json
                newJson[i] = value
                @adjustIndex document.index, location[0...index], last, json, newJson
              json[i] = value

        defView: (context, namespace, type, def)->
          context.views[namespace][type] = compile def

      Handlebars.registerHelper 'view', (itemName, namespace, options)->
        if typeof itemName != 'string' || (namespace && options && typeof namespace != 'string') then throw new Error("View must be called with one or two strings")
        if !options?
          options = namespace
          namespace = null
        item = this[itemName]
        context = options.data.context
        context = Object.assign {}, context, location: [context.location..., itemName]
        if namespace then context.namespace = namespace
        node = options.data.domdom.baseRender(parseHtml('<div></div>'), item, context)
        if node.nodeType == 1 then node.outerHTML else node.data

      Handlebars.registerHelper 'ref', (item, namespace, options)->
        if !Array.isArray(item) && typeof item != 'string' then throw new Error("Ref must be called with an array or a string and optionally another string")
        if options? && namespace && typeof namespace != 'string' then throw new Error("Ref's namespace  must be a string")
        if !options?
          options = namespace
          namespace = null
        context = options.data.context
        location = resolvePath context.top, (if typeof item == 'string' then stringToLocation item else item)
        context = Object.assign {}, context, location: location
        if namespace then context.namespace = namespace
        if json = options.data.domdom.getPath context.top, context.top.contents, location
          node = options.data.domdom.baseRender(parseHtml('<div></div>'), json, context)
          if node.nodeType == 1 then node.outerHTML else node.data
        else ""

Command processor clients (if using client/server)

      messages =
        batch: (con, items)->
          con.batchLevel++
          for item in items
            handleMessage con, item
          con.batchLevel--
        document: (con, doc)->
          con.document = doc
          con.context.top = doc
          con.dom = con.dd.render con.dom, doc, con.context
          con.context.views = con.document.compiledViews
          console.log "document:", doc
        set: (con, path, value)->
          con.dd.setPath con.document, con.document.contents, path, value
          if !value?.type? then path.pop()
          con.changedJson.add locationToString path
          path
        splice: (con, path, start, length, items...)->
          obj = con.dd.getPath con.document, con.document.contents, path
          for i in [start...obj.length]
            p = [path..., i]
            con.dd.adjustIndex con.document.index, p, obj, obj[i], items[i - start]
            con.changedJson.add locationToString p
          obj.splice start, length, items...
        defView: (con, namespace, type, def)-> con.dd.defView con.context, namespace, type, def

#Change handler

      handleChanges = (ctx)->
        if ctx.batchLevel == 0
          for path from ctx.changedJson
            loc = stringToLocation path
            ctx.dd.rerender ctx.dd.getPath(ctx.doc, ctx.doc.contents, loc), Object.assign({}, ctx, location: loc), (dom)->
              if dom.getAttribute('data-top')? then ctx.setTopFunc dom
          ctx.changedJson.clear()
          ctx.dd.runRefreshQueue()

      change = (ctx, path)->
        ctx.changedJson.add locationToString path
        if ctx.batchLevel == 0 then handleChanges ctx

      initChangeContext = (dd, ctx, doc, setTopFunc)->
        ctx.batchLevel = 0
        ctx.changedJson = new Set()
        ctx.dd = dd
        ctx.doc = doc
        ctx.setTopFunc = setTopFunc

`batch(CTX, FUNC)` executes FUNC, queuing up re-rendering requests and then processing the requests all at once after FUNC finishes.

      batch = (ctx, func)->
        if typeof ctx.batchLevel == 'number'
            ctx.batchLevel++
            try
                func()
            finally
                ctx.batchLevel--
                handleChanges ctx
        else func()

#Local Code

      isDocPathSym = Symbol("isDocPath")

      partsSym = Symbol("parts")

      syms = [isDocPathSym, partsSym]

`isDocPath(obj)` returns true if the object is a docPath

      isDocPath = (obj)-> obj[isDocPathSym]

`docPathParts(docp)` returns the "parts" you used to create the doc path: [dd, ctx, path]

      docPathParts = (docp)-> docp[partsSym]

`docPathParent(docp)` returns a parent DocPath for docp (i.e. a DocPath without the last path element)

      docPathParent = (docp)->
        [dd, ctx, path] = docPathParts docp
        if !path.length then docp
        else docPath dd, ctx, path[...-1]

`docPathValue(docp)` returns the value for the DocPath

      docPathValue = (docp)->
        [dd, ctx, path] = docPathParts docp
        docValue(dd, ctx, path)

`docPath(dd, ctx, path = [])` creates a DocPath

      docPath = (dd, ctx, path = [])->
        new Proxy {},
          get: (target, name)->
            if name == isDocPathSym then true
            else if name == partsSym then [dd, ctx, path]
            else if name == 'toString()' then ()-> printDocPath(dd, ctx, path)
            else docValue dd, ctx, [...path, name]
          set: (target, name, value)->
            if !(name in syms)
              path = [...path, name]
              dd.setPath ctx.top, ctx.top.contents, path, value
              change ctx, resolvePath ctx.top, path

      docValue = (dd, ctx, path, value)->
        if value == undefined
            val = dd.getPath ctx.top, ctx.top.contents, path
            if val == undefined then val
            else docValue dd, ctx, path, dd.getPath ctx.top, ctx.top.contents, path
        else if Array.isArray value then docPath dd, ctx, path
        else if typeof value == 'object' then docPath dd, ctx, path
        else value

      eventPaths = (dd, ctx, evt)->
        node = evt.srcElement
        fullPath = stringToLocation(node.getAttribute('data-path-full'))
        path = stringToLocation(node.getAttribute('data-path'))
        objPath = stringToLocation(node.closest('[data-location]').getAttribute('data-location'))
        obj = dd.getPath ctx.top, ctx.top.contents, objPath
        value = dd.getPath ctx.top, ctx.top.contents, [objPath..., path...]
        [fullPath, obj, objPath, path, value]

      dispatchClick = (dd, ctx, handlers, evt)->
        [fullPath, obj, objPath, path, value] = eventPaths dd, ctx, evt
        docp = docPath(dd, ctx, fullPath)
        batch ctx, ->
          handlers[[obj.type, locationToString(path), "click"].join(',')]?(docp, obj, objPath, path, value, evt)
          handlers[obj.type]?[locationToString(path)]?.click?(docp, obj, objPath, path, value, evt)

      dispatchKey = (dd, ctx, handlers, evt)->
        [fullPath, obj, objPath, path, value] = eventPaths dd, ctx, evt
        docp = docPath(dd, ctx, fullPath)
        batch ctx, ->
          handlers[[obj.type, locationToString(path), "key"].join(',')]?(docp, obj, objPath, path, value, evt)
          handlers[obj.type]?[locationToString(path)]?.key?(docp, obj, objPath, path, value, evt)

      dispatchSet = (dd, ctx, handlers, evt)->
        [fullPath, obj, objPath, path, value] = eventPaths dd, ctx, evt
        docp = docPath(dd, ctx, fullPath)
        batch ctx, ->
          handlers[[obj.type, locationToString(path), "set"].join(',')]?(docp, obj, objPath, path, value, evt)
          handlers[obj.type]?[locationToString(path)]?.set?(docp, obj, objPath, path, value, evt)

patternHandler(DD, CTX, HANDLERS) returns an event handler and makes it easy to define event handlers for types and paths

HANDLERS specify event handlers in one of two ways (you can mix them, using whichever is more convenient):
- "TYPE,FIELD,EVENT": (OBJ, PATH, KEY, VALUE, EVT)=> ...
- TYPE: {FIELD: {EVENT: (OBJ, PATH, KEY, VALUE, EVT)=> ...}}

      patternHandler = (dd, ctx, handlers)->
        ctx.handler =
          clickButton: (evt)-> dispatchClick dd, ctx, handlers, evt
          changedValue: (evt)-> dispatchSet dd, ctx, handlers, evt

#Client Code

Connect to WebSocket server

      handleMessage = (con, [cmd, args...])->
        verbose "Message: #{JSON.stringify [cmd, args...]}"
        messages[cmd](con, args...)
        if con.batchLevel == 0
          for path from con.changedJson
            path = stringToLocation path
            con.dd.rerender con.dd.getPath(con.document, con.document.contents, path), Object.assign({}, con.context, location: path), (dom)->
              if dom?.getAttribute('data-top')? then con.dom = dom
          con.changedJson.clear()

      connect = (con, url)->
        con.dd = new Domdom query('#top')
        con.batchLevel = 0
        con.changedJson = new Set()
        con.dom = query('#top')
        con.context = Object.assign {}, con.context,
          top: null
          handler:
            keyPress: (evt)->
              if key = keyCode evt
                ws.send JSON.stringify(['key', key, stringToLocation evt.currentTarget.closest('[data-location]').getAttribute 'data-location'])
            clickButton: (evt)->
              path = stringToLocation evt.currentTarget.getAttribute('data-path-full')
              name = path.pop()
              ws.send JSON.stringify ['click', name, path]
            changedValue: (evt, value)->
              node = evt.currentTarget
              ws.send JSON.stringify ['set', stringToLocation(node.getAttribute 'data-path-full'), value ? node.value]
        ws = con.socket = new WebSocket url
        ws.onmessage = (msg)->
          verbose "MESSAGE:", msg
          handleMessage con, JSON.parse msg.data
        ws

      Object.assign Domdom, {
        locationToString
        stringToLocation
        query
        queryAll
        find
        parseHtml
        keyCode
        connect
        messages
        docPath
        docPathValue
        isDocPath
        docPathParts
        docPathParent
        initChangeContext
        batch
        change
        patternHandler
        dispatchClick
        dispatchKey
        dispatchSet
        setVerbose
        isRefreshing
        takeFocusForScript
      }

      Domdom
