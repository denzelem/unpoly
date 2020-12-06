u = up.util
e = up.element

class up.ResponseDoc

  constructor: (options) ->
    # We wrap <noscript> tags into a <div> for two reasons:
    #
    # (1) IE11 and Edge cannot find <noscript> tags with jQuery or querySelector() or
    #     getElementsByTagName() when the tag was created by DOMParser. This is a bug.
    #     https://developer.microsoft.com/en-us/microsoft-edge/platform/issues/12453464/
    #
    # (2) The children of a <nonscript> tag are expected to be a verbatim text node
    #     in a scripting-capable browser. However, due to rules in the DOMParser spec,
    #     the children are parsed into actual DOM nodes. This confuses libraries that
    #     work with <noscript> tags, such as lazysizes.
    #     http://w3c.github.io/DOM-Parsing/#dom-domparser-parsefromstring
    #
    # We will unwrap the wrapped <noscript> tags when a fragment is requested with
    # #first(), and only in the requested fragment.
    @noscriptWrapper = new up.HTMLWrapper('noscript')

    # We strip <script> tags from the HTML.
    # If you need a fragment update to call JavaScript code, call it from a compiler
    # ([Google Analytics example](https://makandracards.com/makandra/41488-using-google-analytics-with-unpoly)).
    @scriptStripper = new up.HTMLWrapper('script')

    @root =
      @parseDocument(options) || @parseFragment(options) || @parseContent(options)

  parseDocument: (options) ->
    return @parse(options.document, e.createDocumentFromHTML)

  parseContent: (options) ->
    # Parsing { inner } is the last option we try. It should always succeed in case someone
    # tries `up.layer.open()` without any args. Hence we set the innerHTML to an empty string.
    content = options.content || ''
    target = options.target || up.fail("must pass a { target } when passing { content }")

    # Conjure an element that will later match options.target in @select()
    matchingElement = e.createFromSelector(target)

    if u.isString(content)
      content = @wrapHTML(content)
      # Don't use e.createFromHTML() here, since content may be a text node.
      matchingElement.innerHTML = content
    else
      matchingElement.appendChild(content)

    return matchingElement

  parseFragment: (options) ->
    return @parse(options.fragment)

  parse: (value, parseFn = e.createFromHTML) ->
    if u.isString(value)
      value = @wrapHTML(value)
      value = parseFn(value)
    value

  rootSelector: ->
    up.fragment.toTarget(@root)

  wrapHTML: (html) ->
    html = @noscriptWrapper.wrap(html)
    html = @scriptStripper.strip(html)
    html

  getTitle: ->
    # Cache since multiple plans will query this.
    # Use a flag so we can cache an empty result.
    unless @titleParsed
      @title = @root.querySelector("head title")?.textContent
      @titleParsed = true
    return @title

  select: (selector) ->
    e.subtree(@root, selector)[0]

  finalizeElement: (element) ->
    # Restore <noscript> tags so they become available to compilers.
    @noscriptWrapper.unwrap(element)
