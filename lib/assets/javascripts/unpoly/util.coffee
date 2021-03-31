###**
Utility functions
=================

The `up.util` module contains functions to facilitate the work with basic JavaScript
values like lists, strings or functions.

You will recognize many functions form other utility libraries like [Lodash](https://lodash.com/).
While feature parity with Lodash is not a goal of `up.util`, you might find it sufficient
to not include another library in your asset bundle.

@module up.util
###
up.util = do ->

  ###**
  A function that does nothing.

  @function up.util.noop
  @experimental
  ###
  noop = (->)

  ###**
  A function that returns a resolved promise.

  @function up.util.asyncNoop
  @internal
  ###
  asyncNoop = -> Promise.resolve()

  ###**
  Ensures that the given function can only be called a single time.
  Subsequent calls will return the return value of the first call.

  Note that this is a simple implementation that
  doesn't distinguish between argument lists.

  @function up.util.memoize
  @internal
  ###
  memoize = (func) ->
    cachedValue = undefined
    cached = false
    (args...) ->
      if cached
        return cachedValue
      else
        cached = true
        return cachedValue = func.apply(this, args)

  ###**
  Returns if the given port is the default port for the given protocol.

  @function up.util.isStandardPort
  @internal
  ###  
  isStandardPort = (protocol, port) ->
    port = port.toString()
    ((port == "" || port == "80") && protocol == 'http:') || (port == "443" && protocol == 'https:')

  NORMALIZE_URL_DEFAULTS = {
    host: 'cross-domain'
    stripTrailingSlash: false
    search: true
    hash: false
  }

  ###**
  Normalizes relative paths and absolute paths to a full URL
  that can be checked for equality with other normalized URLs.
  
  By default hashes are ignored, search queries are included.
  
  @function up.util.normalizeURL
  @param {boolean} [options.host='cross-domain']
    Whether to include protocol, hostname and port in the normalized URL.
  @param {boolean} [options.hash=false]
    Whether to include an `#hash` anchor in the normalized URL
  @param {boolean} [options.search=true]
    Whether to include a `?query` string in the normalized URL
  @param {boolean} [options.stripTrailingSlash=false]
    Whether to strip a trailing slash from the pathname
  @internal
  ###
  normalizeURL = (urlOrAnchor, options) ->
    options = newOptions(options, NORMALIZE_URL_DEFAULTS)

    parts = parseURL(urlOrAnchor)
    normalized = ''

    if options.host == 'cross-domain'
      options.host = isCrossOrigin(parts)

    if options.host
      normalized += parts.protocol + "//" + parts.hostname
      # Once we drop IE11 we can just use { host }, which contains port and hostname
      # and also handles standard ports.
      # See https://developer.mozilla.org/en-US/docs/Web/API/URL/host
      unless isStandardPort(parts.protocol, parts.port)
        normalized += ":#{parts.port}"

    pathname = parts.pathname
    if options.stripTrailingSlash
      pathname = pathname.replace(/\/$/, '')
    normalized += pathname

    if options.search
      normalized += parts.search

    if options.hash
      normalized += parts.hash

    normalized

  urlWithoutHost = (url) ->
    normalizeURL(url, host: false)

  matchURLs = (leftURL, rightURL) ->
    return normalizeURL(leftURL) == normalizeURL(rightURL)

  # We're calling isCrossOrigin() a lot.
  # Accessing location.protocol and location.hostname every time
  # is much slower than comparing cached strings.
  # https://jsben.ch/kBATt
  APP_PROTOCOL = location.protocol
  APP_HOSTNAME = location.hostname

  isCrossOrigin = (urlOrAnchor) ->
    # If the given URL does not contain a hostname we know it cannot be cross-origin.
    # In that case we don't need to parse the URL.
    if isString(urlOrAnchor) && urlOrAnchor.indexOf('//') == -1
      return false

    parts = parseURL(urlOrAnchor)
    return APP_HOSTNAME != parts.hostname || APP_PROTOCOL != parts.protocol

  ###**
  Parses the given URL into components such as hostname and path.

  If the given URL is not fully qualified, it is assumed to be relative
  to the current page.

  @function up.util.parseURL
  @return {Object}
    The parsed URL as an object with
    `protocol`, `hostname`, `port`, `pathname`, `search` and `hash`
    properties.
  @stable
  ###
  parseURL = (urlOrLink) ->
    if isJQuery(urlOrLink)
      # In case someone passed us a $link, unwrap it
      link = up.element.get(urlOrLink)
    else if urlOrLink.pathname
      # If we are handed a parsed URL, just return it
      link = urlOrLink
    else
      link = document.createElement('a')
      link.href = urlOrLink

    # In IE11 the #hostname and #port properties of unqualified URLs are empty strings.
    # We can fix this by setting the link's { href } on the link itself.
    unless link.hostname
      link.href = link.href

    # Some IEs don't include a leading slash in the #pathname property.
    # We have confirmed this in IE11 and earlier.
    unless link.pathname[0] == '/'
      # Only copy the link into an object when we need to (to change a property).
      # Note that we're parsing a lot of URLs for [up-active].
      link = pick(link, ['protocol', 'hostname', 'port', 'pathname', 'search', 'hash'])
      link.pathname = '/' + link.pathname

    link

  ###**
  @function up.util.normalizeMethod
  @internal
  ###
  normalizeMethod = (method) ->
    if method
      method.toUpperCase()
    else
      'GET'

  ###**
  @function up.util.methodAllowsPayload
  @internal
  ###
  methodAllowsPayload = (method) ->
    method != 'GET' && method != 'HEAD'

  # Remove with IE11
  assignPolyfill = (target, sources...) ->
    for source in sources
      for own key, value of source
        target[key] = value
    target

  ###**
  Merge the own properties of one or more `sources` into the `target` object.

  @function up.util.assign
  @param {Object} target
  @param {Array<Object>} sources...
  @stable
  ###
  assign = Object.assign || assignPolyfill

  # Remove with IE11
  valuesPolyfill = (object) ->
    value for key, value of object

  ###**
  Returns an array of values of the given object.

  @function up.util.values
  @param {Object} object
  @return {Array<string>}
  @stable
  ###
  objectValues = Object.values || valuesPolyfill

  iteratee = (block) ->
    if isString(block)
      (item) -> item[block]
    else
      block

  ###**
  Translate all items in an array to new array of items.

  @function up.util.map
  @param {Array} array
  @param {Function(element, index): any|String} block
    A function that will be called with each element and (optional) iteration index.

    You can also pass a property name as a String,
    which will be collected from each item in the array.
  @return {Array}
    A new array containing the result of each function call.
  @stable
  ###
  map = (array, block) ->
    return [] if array.length == 0
    block = iteratee(block)
    for item, index in array
      block(item, index)

  ###**
  @function up.util.mapObject
  @internal
  ###
  mapObject = (array, pairer) ->
    merger = (object, pair) ->
      object[pair[0]] = pair[1]
      return object
    map(array, pairer).reduce(merger, {})

  ###**
  Calls the given function for each element (and, optional, index)
  of the given array.

  @function up.util.each
  @param {Array} array
  @param {Function(element, index)} block
    A function that will be called with each element and (optional) iteration index.
  @stable
  ###
  each = map # note that the native Array.forEach is very slow (https://jsperf.com/fast-array-foreach)

  eachIterator = (iterator, callback) ->
    while (entry = iterator.next()) && !entry.done
      callback(entry.value)

  ###**
  Calls the given function for the given number of times.

  @function up.util.times
  @param {number} count
  @param {Function()} block
  @stable
  ###
  times = (count, block) ->
    block(iteration) for iteration in [0..(count - 1)]

  ###**
  Returns whether the given argument is `null`.

  @function up.util.isNull
  @param object
  @return {boolean}
  @stable
  ###
  isNull = (object) ->
    object == null

  ###**
  Returns whether the given argument is `undefined`.

  @function up.util.isUndefined
  @param object
  @return {boolean}
  @stable
  ###
  isUndefined = (object) ->
    object == undefined

  ###**
  Returns whether the given argument is not `undefined`.

  @function up.util.isDefined
  @param object
  @return {boolean}
  @stable
  ###
  isDefined = (object) ->
    !isUndefined(object)

  ###**
  Returns whether the given argument is either `undefined` or `null`.

  Note that empty strings or zero are *not* considered to be "missing".

  For the opposite of `up.util.isMissing()` see [`up.util.isGiven()`](/up.util.isGiven).

  @function up.util.isMissing
  @param object
  @return {boolean}
  @stable
  ###
  isMissing = (object) ->
    isUndefined(object) || isNull(object)

  ###**
  Returns whether the given argument is neither `undefined` nor `null`.

  Note that empty strings or zero *are* considered to be "given".

  For the opposite of `up.util.isGiven()` see [`up.util.isMissing()`](/up.util.isMissing).

  @function up.util.isGiven
  @param object
  @return {boolean}
  @stable
  ###
  isGiven = (object) ->
    !isMissing(object)

  # isNan = (object) ->
  #   isNumber(value) && value != +value

  ###**
  Return whether the given argument is considered to be blank.

  By default, this function returns `true` for:

  - `undefined`
  - `null`
  - Empty strings
  - Empty arrays
  - A plain object without own enumerable properties

  All other arguments return `false`.

  To check implement blank-ness checks for user-defined classes,
  see `up.util.isBlank.key`.

  @function up.util.isBlank
  @param value
    The value is to check.
  @return {boolean}
    Whether the value is blank.
  @stable
  ###
  isBlank = (value) ->
    if isMissing(value)
      return true
    if isObject(value) && value[isBlank.key]
      return value[isBlank.key]()
    if isString(value) || isList(value)
      return value.length == 0
    if isOptions(value)
      return Object.keys(value).length == 0
    return false

  ###**
  This property contains the name of a method that user-defined classes
  may implement to hook into the `up.util.isBlank()` protocol.

  \#\#\# Example

  We have a user-defined `Account` class that we want to use with `up.util.isBlank()`:

  ```
  class Account {
    constructor(email) {
      this.email = email
    }

    [up.util.isBlank.key]() {
      return up.util.isBlank(this.email)
    }
  }
  ```

  Note that the protocol method is not actually named `'up.util.isBlank.key'`.
  Instead it is named after the *value* of the `up.util.isBlank.key` property.
  To do so, the code sample above is using a
  [computed property name](https://medium.com/front-end-weekly/javascript-object-creation-356e504173a8)
  in square brackets.

  We may now use `Account` instances with `up.util.isBlank()`:

  ```
  foo = new Account('foo@foo.com')
  bar = new Account('')

  console.log(up.util.isBlank(foo)) // prints false
  console.log(up.util.isBlank(bar)) // prints true
  ```

  @property up.util.isBlank.key
  @experimental
  ###
  isBlank.key = 'up.util.isBlank'

  ###**
  Returns the given argument if the argument is [present](/up.util.isPresent),
  otherwise returns `undefined`.

  @function up.util.presence
  @param value
  @param {Function(value): boolean} [tester=up.util.isPresent]
    The function that will be used to test whether the argument is present.
  @return {any|undefined}
  @stable
  ###
  presence = (value, tester = isPresent) ->
    if tester(value) then value else undefined

  ###**
  Returns whether the given argument is not [blank](/up.util.isBlank).

  @function up.util.isPresent
  @param object
  @return {boolean}
  @stable
  ###
  isPresent = (object) ->
    !isBlank(object)

  ###**
  Returns whether the given argument is a function.

  @function up.util.isFunction
  @param object
  @return {boolean}
  @stable
  ###
  isFunction = (object) ->
    typeof(object) == 'function'

  ###**
  Returns whether the given argument is a string.

  @function up.util.isString
  @param object
  @return {boolean}
  @stable
  ###
  isString = (object) ->
    typeof(object) == 'string' || object instanceof String

  ###**
  Returns whether the given argument is a boolean value.

  @function up.util.isBoolean
  @param object
  @return {boolean}
  @stable
  ###
  isBoolean = (object) ->
    typeof(object) == 'boolean' || object instanceof Boolean

  ###**
  Returns whether the given argument is a number.

  Note that this will check the argument's *type*.
  It will return `false` for a string like `"123"`.

  @function up.util.isNumber
  @param object
  @return {boolean}
  @stable
  ###
  isNumber = (object) ->
    typeof(object) == 'number' || object instanceof Number

  ###**
  Returns whether the given argument is an options hash,

  Differently from [`up.util.isObject()`], this returns false for
  functions, jQuery collections, promises, `FormData` instances and arrays.

  @function up.util.isOptions
  @param object
  @return {boolean}
  @internal
  ###
  isOptions = (object) ->
    typeof(object) == 'object' && !isNull(object) && (isUndefined(object.constructor) || object.constructor == Object)

  ###**
  Returns whether the given argument is an object.

  This also returns `true` for functions, which may behave like objects in JavaScript.

  @function up.util.isObject
  @param object
  @return {boolean}
  @stable
  ###
  isObject = (object) ->
    typeOfResult = typeof(object)
    (typeOfResult == 'object' && !isNull(object)) || typeOfResult == 'function'

  ###**
  Returns whether the given argument is a [DOM element](https://developer.mozilla.org/de/docs/Web/API/Element).

  @function up.util.isElement
  @param object
  @return {boolean}
  @stable
  ###
  isElement = (object) ->
    object instanceof Element

  ###**
  Returns whether the given argument is a [regular expression](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/RegExp).

  @function up.util.isRegExp
  @param object
  @return {boolean}
  @internal
  ###
  isRegExp = (object) ->
    object instanceof RegExp

  ###**
  Returns whether the given argument is a [jQuery collection](https://learn.jquery.com/using-jquery-core/jquery-object/).

  @function up.util.isJQuery
  @param object
  @return {boolean}
  @stable
  ###
  isJQuery = (object) ->
    # We cannot do `object instanceof jQuery` since window.jQuery might not be set
    !!object?.jquery

  ###**
  @function up.util.isElementish
  @param object
  @return {boolean}
  @internal
  ###
  isElementish = (object) ->
    !!(object && (object.addEventListener || object[0]?.addEventListener))

  ###**
  Returns whether the given argument is an object with a `then` method.

  @function up.util.isPromise
  @param object
  @return {boolean}
  @stable
  ###
  isPromise = (object) ->
    isObject(object) && isFunction(object.then)

  ###**
  Returns whether the given argument is an array.

  @function up.util.isArray
  @param object
  @return {boolean}
  @stable
  ###
  # https://developer.mozilla.org/de/docs/Web/JavaScript/Reference/Global_Objects/Array/isArray
  isArray = Array.isArray

  ###**
  Returns whether the given argument is a `FormData` instance.

  Always returns `false` in browsers that don't support `FormData`.

  @function up.util.isFormData
  @param object
  @return {boolean}
  @internal
  ###
  isFormData = (object) ->
    object instanceof FormData

  ###**
  Converts the given [array-like value](/up.util.isList) into an array.

  If the given value is already an array, it is returned unchanged.

  @function up.util.toArray
  @param object
  @return {Array}
  @stable
  ###
  toArray = (value) ->
    if isArray(value)
      value
    else
      copyArrayLike(value)

  ###**
  Returns whether the given argument is an array-like value.

  Return true for `Array`, a
  [`NodeList`](https://developer.mozilla.org/en-US/docs/Web/API/NodeList),
   the [arguments object](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions/arguments)
   or a jQuery collection.

  Use [`up.util.isArray()`](/up.util.isArray) to test whether a value is an actual `Array`.

  @function up.util.isList
  @param value
  @return {boolean}
  @experimental
  ###
  isList = (value) ->
    isArray(value) ||
      isNodeList(value) ||
      isArguments(value) ||
      isJQuery(value) ||
      isHTMLCollection(value)

  ###**
  Returns whether the given value is a [`NodeList`](https://developer.mozilla.org/en-US/docs/Web/API/NodeList).

  `NodeLists` are array-like objects returned by [`document.querySelectorAll()`](https://developer.mozilla.org/en-US/docs/Web/API/Element/querySelectorAll).

  @function up.util.isNodeList
  @param value
  @return {boolean}
  @internal
  ###
  isNodeList = (value) ->
    value instanceof NodeList

  isHTMLCollection = (value) ->
    value instanceof HTMLCollection

  ###**
  Returns whether the given value is an [arguments object](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions/arguments).

  @function up.util.isArguments
  @param value
  @return {boolean}
  @internal
  ###
  isArguments = (value) ->
    Object.prototype.toString.call(value) == '[object Arguments]'

  nullToUndefined = (value) ->
    if isNull(value)
      return undefined
    else
      return value

  ###**
  @function up.util.wrapList
  @return {Array|NodeList|jQuery}
  @internal
  ###
  wrapList = (value) ->
    if isList(value)
      value
    else if isMissing(value)
      []
    else
      [value]

  ###**
  Returns a shallow copy of the given value.

  \#\#\# Copying protocol

  - By default `up.util.copy()` can copy [array-like values](/up.util.isList),
    plain objects and `Date` instances.
  - Array-like objects are copied into new arrays.
  - Unsupported types of values are returned unchanged.
  - To make the copying protocol work with user-defined class,
    see `up.util.copy.key`.
  - Immutable objects, like strings or numbers, do not need to be copied.

  @function up.util.copy
  @param {any} object
  @return {any}
  @stable
  ###
  copy = (value)  ->
    if isObject(value) && value[copy.key]
      value = value[copy.key]()
    else if isList(value)
      value = copyArrayLike(value)
      # copied = true
    else if isOptions(value)
      value = assign({}, value)
      # copied = true
#    if copied && deep
#      for k, v of value
#        value[k] = copy(v, true)
    value

  copyArrayLike = (arrayLike) ->
    Array.prototype.slice.call(arrayLike)

  ###**
  This property contains the name of a method that user-defined classes
  may implement to hook into the `up.util.copy()` protocol.

  \#\#\# Example

  We have a user-defined `Account` class that we want to use with `up.util.copy()`:

  ```
  class Account {
    constructor(email) {
      this.email = email
    }

    [up.util.copy.key]() {
      return new Account(this.email)
    }
  }
  ```

  Note that the protocol method is not actually named `'up.util.copy.key'`.
  Instead it is named after the *value* of the `up.util.copy.key` property.
  To do so, the code sample above is using a
  [computed property name](https://medium.com/front-end-weekly/javascript-object-creation-356e504173a8)
  in square brackets.

  We may now use `Account` instances with `up.util.copy()`:

  ```
  original = new User('foo@foo.com')

  copy = up.util.copy(original)
  console.log(copy.email) // prints 'foo@foo.com'

  original.email = 'bar@bar.com' // change the original
  console.log(copy.email) // still prints 'foo@foo.com'
  ```

  @property up.util.copy.key
  @param {string} key
  @experimental
  ###
  copy.key = 'up.util.copy'

  # Implement up.util.copy protocol for Date
  Date.prototype[copy.key] = -> new Date(+@)

#  ###**
#  Returns a deep copy of the given array or object.
#
#  @function up.util.deepCopy
#  @param {Object|Array} object
#  @return {Object|Array}
#  @internal
#  ###
#  deepCopy = (object) ->
#    copy(object, true)

  ###**
  Creates a new object by merging together the properties from the given objects.

  @function up.util.merge
  @param {Array<Object>} sources...
  @return Object
  @stable
  ###
  merge = (sources...) ->
    assign({}, sources...)

  ###**
  @function up.util.mergeDefined
  @param {Array<Object>} sources...
  @return Object
  @internal
  ###
  mergeDefined = (sources...) ->
    result = {}
    for source in sources
      if source
        for key, value of source
          if isDefined(value)
            result[key] = value
    result

#  ###**
#  Creates a new object by recursively merging together the properties from the given objects.
#
#  @function up.util.deepMerge
#  @param {Array<Object>} sources...
#  @return Object
#
#  @internal
#  ###
#  deepMerge = (sources...) ->
#    deepAssign({}, sources...)
#
#  ###**
#  @function up.util.deepAssign
#  @param {Array<Object>} sources...
#  @return Object
#  ###
#  deepAssign = (target, sources...) ->
#    for source in sources
#      for key, newValue of source
#        if isOptions(newValue)
#          oldValue = target[key]
#          if isOptions(oldValue)
#            newValue = deepMerge(oldValue, newValue)
#        target[key] = newValue
#    target

  ###**
  Creates an options hash from the given argument and some defaults.

  The semantics of this function are confusing.
  We want to get rid of this in the future.

  @function up.util.options
  @param {Object} object
  @param {Object} [defaults]
  @return {Object}
  @internal
  ###
  newOptions = (object, defaults) ->
    if defaults
      merge(defaults, object)
    else if object
      copy(object)
    else
      {}

  parseArgIntoOptions = (args, argKey) ->
    options = extractOptions(args)
    if isDefined(args[0])
      options = copy(options)
      options[argKey] = args[0]
    options

  ###**
  Passes each element in the given [array-like value](/up.util.isList) to the given function.
  Returns the first element for which the function returns a truthy value.

  If no object matches, returns `undefined`.

  @function up.util.find
  @param {List<T>} list
  @param {Function(value): boolean} tester
  @return {T|undefined}
  @stable
  ###
  findInList = (list, tester) ->
    tester = iteratee(tester)
    match = undefined
    for element in list
      if tester(element)
        match = element
        break
    match

  ###**
  Returns whether the given function returns a truthy value
  for any element in the given [array-like value](/up.util.isList).

  @function up.util.some
  @param {List} list
  @param {Function(value, index): boolean} tester
    A function that will be called with each element and (optional) iteration index.

  @return {boolean}
  @stable
  ###
  some = (list, tester) ->
    !!findResult(list, tester)

  ###**
  Consecutively calls the given function which each element
  in the given array. Returns the first truthy return value.

  Returned `undefined` iff the function does not return a truthy
  value for any element in the array.

  @function up.util.findResult
  @param {Array} array
  @param {Function(element): any} tester
    A function that will be called with each element and (optional) iteration index.

  @return {any|undefined}
  @experimental
  ###
  findResult = (array, tester) ->
    tester = iteratee(tester)
    for element, index in array
      if result = tester(element, index)
        return result
    return undefined

  ###**
  Returns whether the given function returns a truthy value
  for all elements in the given [array-like value](/up.util.isList).

  @function up.util.every
  @param {List} list
  @param {Function(element, index): boolean} tester
    A function that will be called with each element and (optional) iteration index.

  @return {boolean}
  @experimental
  ###
  every = (list, tester) ->
    tester = iteratee(tester)
    match = true
    for element, index in list
      unless tester(element, index)
        match = false
        break
    match

  ###**
  Returns all elements from the given array that are
  neither `null` or `undefined`.

  @function up.util.compact
  @param {Array<T>} array
  @return {Array<T>}
  @stable
  ###
  compact = (array) ->
    filterList array, isGiven

  compactObject = (object) ->
    pickBy(object, isGiven)

  ###**
  Returns the given array without duplicates.

  @function up.util.uniq
  @param {Array<T>} array
  @return {Array<T>}
  @stable
  ###
  uniq = (array) ->
    return array if array.length < 2
    setToArray(arrayToSet(array))

  ###**
  This function is like [`uniq`](/up.util.uniq), accept that
  the given function is invoked for each element to generate the value
  for which uniquness is computed.

  @function up.util.uniqBy
  @param {Array} array
  @param {Function(value): any} array
  @return {Array}
  @experimental
  ###
  uniqBy = (array, mapper) ->
    return array if array.length < 2
    mapper = iteratee(mapper)
    set = new Set()
    filterList array, (elem, index) ->
      mapped = mapper(elem, index)
      if set.has(mapped)
        false
      else
        set.add(mapped)
        true

  ###**
  @function up.util.setToArray
  @internal
  ###
  setToArray = (set) ->
    array = []
    set.forEach (elem) -> array.push(elem)
    array

  ###**
  @function up.util.arrayToSet
  @internal
  ###
  arrayToSet = (array) ->
    set = new Set()
    array.forEach (elem) -> set.add(elem)
    set

  ###**
  Returns all elements from the given [array-like value](/up.util.isList) that return
  a truthy value when passed to the given function.

  @function up.util.filter
  @param {List} list
  @param {Function(value, index): boolean} tester
  @return {Array}
  @stable
  ###
  filterList = (list, tester) ->
    tester = iteratee(tester)
    matches = []
    each list, (element, index) ->
      if tester(element, index)
        matches.push(element)
    matches

  ###**
  Returns all elements from the given [array-like value](/up.util.isList) that do not return
  a truthy value when passed to the given function.

  @function up.util.reject
  @param {List} list
  @param {Function(element, index): boolean} tester
  @return {Array}
  @stable
  ###
  reject = (list, tester) ->
    tester = iteratee(tester)
    filterList(list, (element, index) -> !tester(element, index))

  ###**
  Returns the intersection of the given two arrays.

  Implementation is not optimized. Don't use it for large arrays.

  @function up.util.intersect
  @internal
  ###
  intersect = (array1, array2) ->
    filterList array1, (element) ->
      contains(array2, element)

  ###**
  Waits for the given number of milliseconds, the runs the given callback.

  Instead of `up.util.timer(0, fn)` you can also use [`up.util.task(fn)`](/up.util.task).

  @function up.util.timer
  @param {number} millis
  @param {Function()} callback
  @return {number}
    The ID of the scheduled timeout.

    You may pass this ID to `clearTimeout()` to un-schedule the timeout.
  @stable
  ###
  scheduleTimer = (millis, callback) ->
    setTimeout(callback, millis)

  ###**
  Pushes the given function to the [JavaScript task queue](https://jakearchibald.com/2015/tasks-microtasks-queues-and-schedules/) (also "macrotask queue").

  Equivalent to calling `setTimeout(fn, 0)`.

  Also see `up.util.microtask()`.

  @function up.util.task
  @param {Function()} block
  @stable
  ###
  queueTask = (block) ->
    setTimeout(block, 0)

  ###**
  Pushes the given function to the [JavaScript microtask queue](https://jakearchibald.com/2015/tasks-microtasks-queues-and-schedules/).

  @function up.util.microtask
  @param {Function()} task
  @return {Promise}
    A promise that is resolved with the return value of `task`.

    If `task` throws an error, the promise is rejected with that error.
  @experimental
  ###
  queueMicrotask = (task) ->
    return Promise.resolve().then(task)

  abortableMicrotask = (task) ->
    aborted = false
    queueMicrotask(-> task() unless aborted)
    return -> aborted = true

  ###**
  Returns the last element of the given array.

  @function up.util.last
  @param {Array<T>} array
  @return {T}
  ###
  last = (array) ->
    array[array.length - 1]

  ###**
  Returns whether the given value contains another value.

  If `value` is a string, this returns whether `subValue` is a sub-string of `value`.

  If `value` is an array, this returns whether `subValue` is an element of `value`.

  @function up.util.contains
  @param {Array|string} value
  @param {Array|string} subValue
  @stable
  ###
  contains = (value, subValue) ->
    value.indexOf(subValue) >= 0

  ###**
  Returns whether `object`'s entries are a superset
  of `subObject`'s entries.

  @function up.util.objectContains
  @param {Object} object
  @param {Object} subObject
  @internal
  ###
  objectContains = (object, subObject) ->
    reducedValue = pick(object, Object.keys(subObject))
    isEqual(subObject, reducedValue)

  ###**
  Returns a copy of the given object that only contains
  the given keys.

  @function up.util.pick
  @param {Object} object
  @param {Array} keys
  @stable
  ###
  pick = (object, keys) ->
    filtered = {}
    for key in keys
      if key of object
        filtered[key] = object[key]
    filtered

  pickBy = (object, tester) ->
    tester = iteratee(tester)
    filtered = {}
    for key, value of object
      if tester(value, key, object)
        filtered[key] = object[key]
    return filtered

  ###**
  Returns a copy of the given object that contains all except
  the given keys.

  @function up.util.omit
  @param {Object} object
  @param {Array} keys
  @stable
  ###
  omit = (object, keys) ->
    pickBy(object, (value, key) -> !contains(keys, key))

  ###**
  Returns a promise that will never be resolved.

  @function up.util.unresolvablePromise
  @internal
  ###
  unresolvablePromise = ->
    new Promise(noop)

  ###**
  Removes the given element from the given array.

  This changes the given array.

  @function up.util.remove
  @param {Array<T>} array
    The array to change.
  @param {T} element
    The element to remove.
  @return {T|undefined}
    The removed element, or `undefined` if the array didn't contain the element.
  @stable
  ###
  remove = (array, element) ->
    index = array.indexOf(element)
    if index >= 0
      array.splice(index, 1)
      return element

  ###**
  If the given `value` is a function, calls the function with the given `args`.
  Otherwise it just returns `value`.

  @function up.util.evalOption
  @internal
  ###
  evalOption = (value, args...) ->
    if isFunction(value)
      value(args...)
    else
      value

  ESCAPE_HTML_ENTITY_MAP =
    "&": "&amp;"
    "<": "&lt;"
    ">": "&gt;"
    '"': '&quot;'
    "'": '&#x27;'

  ###**
  Escapes the given string of HTML by replacing control chars with their HTML entities.

  @function up.util.escapeHTML
  @param {string} string
    The text that should be escaped
  @stable
  ###
  escapeHTML = (string) ->
    string.replace /[&<>"']/g, (char) -> ESCAPE_HTML_ENTITY_MAP[char]

  ###**
  @function up.util.escapeRegExp
  @internal
  ###
  escapeRegExp = (string) ->
    # From https://github.com/benjamingr/RegExp.escape
    string.replace(/[\\^$*+?.()|[\]{}]/g, '\\$&')

  pluckKey = (object, key) ->
    value = object[key]
    delete object[key]
    value

  renameKey = (object, oldKey, newKey) ->
    object[newKey] = pluckKey(object, oldKey)

  extractLastArg = (args, tester) ->
    lastArg = last(args)
    if tester(lastArg)
      return args.pop()

#  extractFirstArg = (args, tester) ->
#    firstArg = args[0]
#    if tester(firstArg)
#      return args.shift()

  extractCallback = (args) ->
    extractLastArg(args, isFunction)

  extractOptions = (args) ->
    extractLastArg(args, isOptions) || {}

#  partial = (fn, fixedArgs...) ->
#    return (callArgs...) ->
#      fn.apply(this, fixedArgs.concat(callArgs))
#
#  partialRight = (fn, fixedArgs...) ->
#    return (callArgs...) ->
#      fn.apply(this, callArgs.concat(fixedArgs))

#function throttle(callback, limit) { // From https://jsfiddle.net/jonathansampson/m7G64/
#  var wait = false                   // Initially, we're not waiting
#  return function () {               // We return a throttled function
#    if (!wait) {                     // If we're not waiting
#      callback.call()                // Execute users function
#      wait = true                    // Prevent future invocations
#      setTimeout(function () {       // After a period of time
#        wait = false                 // And allow future invocations
#      }, limit)
#    }
#  }
#}

  identity = (arg) -> arg

#  ###**
#  ###
#  parsePath = (input) ->
#    path = []
#    pattern = /([^\.\[\]\"\']+)|\[\'([^\']+?)\'\]|\[\"([^\"]+?)\"\]|\[([^\]]+?)\]/g
#    while match = pattern.exec(input)
#      path.push(match[1] || match[2] || match[3] || match[4])
#    path

#  ###**
#  Given an async function that will return a promise, returns a proxy function
#  with an additional `.promise` attribute.
#
#  When the proxy is called, the inner function is called.
#  The proxy's `.promise` attribute is available even before the function is called
#  and will resolve when the inner function's returned promise resolves.
#
#  If the inner function does not return a promise, the proxy's `.promise` attribute
#  will resolve as soon as the inner function returns.
#
#  @function up.util.previewable
#  @internal
#  ###
#  previewable = (fun) ->
#    deferred = newDeferred()
#    preview = (args...) ->
#      funValue = fun(args...)
#      # If funValue is again a Promise, it will defer resolution of `deferred`
#      # until `funValue` is resolved.
#      deferred.resolve(funValue)
#      funValue
#    preview.promise = deferred.promise()
#    preview

  ###**
  @function up.util.sequence
  @param {Array<Function()>} functions
  @return {Function()}
    A function that will call all `functions` if called.

  @internal
  ###
  sequence = (functions) ->
    if functions.length == 1
      return functions[0]
    else
      return -> map(functions, (f) -> f())

#  ###**
#  @function up.util.race
#  @internal
#  ###
#  race = (promises...) ->
#    raceDone = newDeferred()
#    each promises, (promise) ->
#      promise.then -> raceDone.resolve()
#    raceDone.promise()

#  ###**
#  Returns `'left'` if the center of the given element is in the left 50% of the screen.
#  Otherwise returns `'right'`.
#
#  @function up.util.horizontalScreenHalf
#  @internal
#  ###
#  horizontalScreenHalf = (element) ->
#    elementDims = element.getBoundingClientRect()
#    elementMid = elementDims.left + 0.5 * elementDims.width
#    screenMid = 0.5 * up.viewport.rootWidth()
#    if elementMid < screenMid
#      'left'
#    else
#      'right'

  ###**
  Flattens the given `array` a single level deep.

  @function up.util.flatten
  @param {Array} array
    An array which might contain other arrays
  @return {Array}
    The flattened array
  @experimental
  ###
  flatten = (array) ->
    flattened = []
    for object in array
      if isList(object)
        flattened.push(object...)
      else
        flattened.push(object)
    flattened

#  flattenObject = (object) ->
#    result = {}
#    for key, value of object
#      result[key] = value
#    result

  ###**
  Maps each element using a mapping function,
  then flattens the result into a new array.

  @function up.util.flatMap
  @param {Array} array
  @param {Function(element)} mapping
  @return {Array}
  @experimental
  ###
  flatMap = (array, block) ->
    flatten map(array, block)

  ###**
  Returns whether the given value is truthy.

  @function up.util.isTruthy
  @internal
  ###
  isTruthy = (object) ->
    !!object

  ###**
  Sets the given callback as both fulfillment and rejection handler for the given promise.

  [Unlike `promise#finally()`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/finally#Description), `up.util.always()` may change the settlement value
  of the given promise.

  @function up.util.always
  @internal
  ###
  always = (promise, callback) ->
    promise.then(callback, callback)

#  mutedFinally = (promise, callback) ->
#    # Use finally() instead of always() so we don't accidentally
#    # register a rejection handler, which would prevent an "Uncaught in Exception" error.
#    finallyDone = promise.finally(callback)
#
#    # Since finally's return value is itself a promise with the same state
#    # as `promise`, we don't want to see "Uncaught in Exception".
#    # If we didn't do this, we couldn't mute rejections in `promise`:
#    #
#    #     promise = new Promise(...)
#    #     promise.finally(function() { ... })
#    #     up.util.muteRejection(promise) // has no effect
#    muteRejection(finallyDone)
#
#    # Return the original promise and *not* finally's return value.
#    return promise

  ###**
  # Registers an empty rejection handler with the given promise.
  # This prevents browsers from printing "Uncaught (in promise)" to the error
  # console when the promise is rejected.
  #
  # This is helpful for event handlers where it is clear that no rejection
  # handler will be registered:
  #
  #     up.on('submit', 'form[up-target]', (event, $form) => {
  #       promise = up.submit($form)
  #       up.util.muteRejection(promise)
  #     })
  #
  # Does nothing if passed a missing value.
  #
  # @function up.util.muteRejection
  # @param {Promise|undefined|null} promise
  # @return {Promise}
  # @internal
  ###
  muteRejection = (promise) ->
    return promise?.catch(noop)

  ###**
  @function up.util.newDeferred
  @internal
  ###
  newDeferred = ->
    resolveFn = undefined
    rejectFn = undefined
    nativePromise = new Promise (givenResolve, givenReject) ->
      resolveFn = givenResolve
      rejectFn = givenReject
    nativePromise.resolve = resolveFn
    nativePromise.reject = rejectFn
    nativePromise.promise = -> nativePromise # just return self
    nativePromise

#  ###**
#  Calls the given block. If the block throws an exception,
#  a rejected promise is returned instead.
#
#  @function up.util.rejectOnError
#  @internal
#  ###
#  rejectOnError = (block) ->
#    try
#      block()
#    catch error
#      Promise.reject(error)

  asyncify = (block) ->
    # The side effects of this should be sync, otherwise we could
    # just do `Promise.resolve().then(block)`.
    try
      return Promise.resolve(block())
    catch error
      return Promise.reject(error)

#  sum = (list, block) ->
#    block = iteratee(block)
#    totalValue = 0
#    for entry in list
#      entryValue = block(entry)
#      if isGiven(entryValue) # ignore undefined/null, like SQL would do
#        totalValue += entryValue
#    totalValue

  isBasicObjectProperty = (k) ->
    Object.prototype.hasOwnProperty(k)

  ###**
  Returns whether the two arguments are equal by value.

  \#\#\# Comparison protocol

  - By default `up.util.isEqual()` can compare strings, numbers,
    [array-like values](/up.util.isList), plain objects and `Date` objects.
  - To make the copying protocol work with user-defined classes,
    see `up.util.isEqual.key`.
  - Objects without a defined comparison protocol are
    defined by reference (`===`).

  @function up.util.isEqual
  @param {any} a
  @param {any} b
  @return {boolean}
    Whether the arguments are equal by value.
  @experimental
  ###
  isEqual = (a, b) ->
    a = a.valueOf() if a?.valueOf # Date, String objects, Number objects
    b = b.valueOf() if b?.valueOf # Date, String objects, Number objects
    if typeof(a) != typeof(b)
      false
    else if isList(a) && isList(b)
      isEqualList(a, b)
    else if isObject(a) && a[isEqual.key]
      a[isEqual.key](b)
    else if isOptions(a) && isOptions(b)
      aKeys = Object.keys(a)
      bKeys = Object.keys(b)
      if isEqualList(aKeys, bKeys)
        every aKeys, (aKey) -> isEqual(a[aKey], b[aKey])
      else
        false
    else
      a == b

  ###**
  This property contains the name of a method that user-defined classes
  may implement to hook into the `up.util.isEqual()` protocol.

  \#\#\# Example

  We have a user-defined `Account` class that we want to use with `up.util.isEqual()`:

  ```
  class Account {
    constructor(email) {
      this.email = email
    }

    [up.util.isEqual.key](other) {
      return this.email === other.email;
    }
  }
  ```

  Note that the protocol method is not actually named `'up.util.isEqual.key'`.
  Instead it is named after the *value* of the `up.util.isEqual.key` property.
  To do so, the code sample above is using a
  [computed property name](https://medium.com/front-end-weekly/javascript-object-creation-356e504173a8)
  in square brackets.

  We may now use `Account` instances with `up.util.isEqual()`:

  ```
  one = new User('foo@foo.com')
  two = new User('foo@foo.com')
  three = new User('bar@bar.com')

  isEqual = up.util.isEqual(one, two)
  // isEqual is now true

  isEqual = up.util.isEqual(one, three)
  // isEqual is now false
  ```

  @property up.util.isEqual.key
  @param {string} key
  @experimental
  ###
  isEqual.key = 'up.util.isEqual'

  isEqualList = (a, b) ->
    a.length == b.length && every(a, (elem, index) -> isEqual(elem, b[index]))

  splitValues = (value, separator = ' ') ->
    if isString(value)
      value = value.split(separator)
      value = map value, (v) -> v.trim()
      value = filterList(value, isPresent)
      value
    else
      wrapList(value)

  endsWith = (string, search) ->
    if search.length > string.length
      false
    else
      string.substring(string.length - search.length) == search

  simpleEase = (x) ->
    # easing: http://fooplot.com/?lang=de#W3sidHlwZSI6MCwiZXEiOiJ4PDAuNT8yKngqeDp4Kig0LXgqMiktMSIsImNvbG9yIjoiIzEzRjIxNyJ9LHsidHlwZSI6MCwiZXEiOiJzaW4oKHheMC43LTAuNSkqcGkpKjAuNSswLjUiLCJjb2xvciI6IiMxQTUyRUQifSx7InR5cGUiOjEwMDAsIndpbmRvdyI6WyItMS40NyIsIjEuNzgiLCItMC41NSIsIjEuNDUiXX1d
    # easing nice: sin((x^0.7-0.5)*pi)*0.5+0.5
    # easing performant: x < 0.5 ? 2*x*x : x*(4 - x*2)-1
    # https://jsperf.com/easings/1
    # Math.sin((Math.pow(x, 0.7) - 0.5) * Math.PI) * 0.5 + 0.5
    if x < 0.5
      2*x*x
    else
      x*(4 - x*2)-1

  wrapValue = (constructor, args...) ->
    if args[0] instanceof constructor
      # This object has gone through instantiation and normalization before.
      args[0]
    else
      new constructor(args...)

#  wrapArray = (objOrArray) ->
#    if isUndefined(objOrArray)
#      []
#    else if isArray(objOrArray)
#      objOrArray
#    else
#      [objOrArray]

  nextUid = 0

  uid = ->
    nextUid++

  ###**
  Returns a copy of the given list, in reversed order.

  @function up.util.reverse
  @param {List<T>} list
  @return {Array<T>}
  @internal
  ###
  reverse = (list) ->
    copy(list).reverse()

#  ###**
#  Returns a copy of the given `object` with the given `prefix` removed
#  from its camel-cased keys.
#
#  @function up.util.unprefixKeys
#  @param {Object} object
#  @param {string} prefix
#  @return {Object}
#  @internal
#  ###
#  unprefixKeys = (object, prefix) ->
#    unprefixed = {}
#    prefixLength = prefix.length
#    for key, value of object
#      if key.indexOf(prefix) == 0
#        key = unprefixCamelCase(key, prefixLength)
#      unprefixed[key] = value
#    unprefixed

  renameKeys = (object, renameKeyFn) ->
    renamed = {}
    for key, value of object
      renamed[renameKeyFn(key)] = value
    return renamed

  camelToKebabCase = (str) ->
    str.replace /[A-Z]/g, (char) -> '-' + char.toLowerCase()

  prefixCamelCase = (str, prefix) ->
    prefix + upperCaseFirst(str)

  unprefixCamelCase = (str, prefix) ->
    pattern = new RegExp('^' + prefix + '(.+)$')
    if match = str.match(pattern)
      return lowerCaseFirst(match[1])

  lowerCaseFirst = (str) ->
    str[0].toLowerCase() + str.slice(1)

  upperCaseFirst = (str) ->
    str[0].toUpperCase() + str.slice(1)

  defineGetter = (object, prop, get) ->
    Object.defineProperty(object, prop, { get })

  defineDelegates = (object, props, targetProvider) ->
    wrapList(props).forEach (prop) ->
      Object.defineProperty object, prop,
        get: ->
          target = targetProvider.call(this)
          value = target[prop]
          if isFunction(value)
            value = value.bind(target)
          return value
        set: (newValue) ->
          target = targetProvider.call(this)
          target[prop] = newValue

  literal = (obj) ->
    result = {}
    for key, value of obj
      if unprefixedKey = unprefixCamelCase(key, 'get_')
        defineGetter(result, unprefixedKey, value)
      else
        result[key] = value
    result

  stringifyArg = (arg) ->
    maxLength = 200
    closer = ''

    if isString(arg)
      string = arg.replace(/[\n\r\t ]+/g, ' ')
      string = string.replace(/^[\n\r\t ]+/, '')
      string = string.replace(/[\n\r\t ]$/, '')
      # string = "\"#{string}\""
      # closer = '"'
    else if isUndefined(arg)
      # JSON.stringify(undefined) is actually undefined
      string = 'undefined'
    else if isNumber(arg) || isFunction(arg)
      string = arg.toString()
    else if isArray(arg)
      string = "[#{map(arg, stringifyArg).join(', ')}]"
      closer = ']'
    else if isJQuery(arg)
      string = "$(#{map(arg, stringifyArg).join(', ')})"
      closer = ')'
    else if isElement(arg)
      string = "<#{arg.tagName.toLowerCase()}"
      for attr in ['id', 'name', 'class']
        if value = arg.getAttribute(attr)
          string += " #{attr}=\"#{value}\""
      string += ">"
      closer = '>'
    else if isRegExp(arg)
      string = arg.toString()
    else # object, array
      try
        string = JSON.stringify(arg)
      catch error
        if error.name == 'TypeError'
          string = '(circular structure)'
        else
          throw error

    if string.length > maxLength
      string = "#{string.substr(0, maxLength)} …"
      string += closer
    string

  SPRINTF_PLACEHOLDERS = /\%[oOdisf]/g

  secondsSinceEpoch = ->
    Math.floor(Date.now() * 0.001)

  ###**
  See https://developer.mozilla.org/en-US/docs/Web/API/Console#Using_string_substitutions

  @function up.util.sprintf
  @internal
  ###
  sprintf = (message, args...) ->
    sprintfWithFormattedArgs(identity, message, args...)

  ###**
  @function up.util.sprintfWithFormattedArgs
  @internal
  ###
  sprintfWithFormattedArgs = (formatter, message, args...) ->
    return '' unless message

    i = 0
    message.replace SPRINTF_PLACEHOLDERS, ->
      arg = args[i]
      arg = formatter(stringifyArg(arg))
      i += 1
      arg

  # Remove with IE11
  allSettled = (promises) ->
    return Promise.all(map(promises, muteRejection))

  parseURL: parseURL
  normalizeURL: normalizeURL
  urlWithoutHost: urlWithoutHost
  matchURLs: matchURLs
  normalizeMethod: normalizeMethod
  methodAllowsPayload: methodAllowsPayload
#  isGoodSelector: isGoodSelector
  assign: assign
  assignPolyfill: assignPolyfill
  copy: copy
  copyArrayLike: copyArrayLike
#  deepCopy: deepCopy
  merge: merge
  mergeDefined: mergeDefined
#  deepAssign: deepAssign
#  deepMerge: deepMerge
  options: newOptions
  parseArgIntoOptions: parseArgIntoOptions
  each: each
  eachIterator: eachIterator
  map: map
  flatMap: flatMap
  mapObject: mapObject
  times: times
  findResult: findResult
  some: some
  every: every
  find: findInList
  filter: filterList
  reject: reject
  intersect: intersect
  compact: compact
  compactObject: compactObject
  uniq: uniq
  uniqBy: uniqBy
  last: last
  isNull: isNull
  isDefined: isDefined
  isUndefined: isUndefined
  isGiven: isGiven
  isMissing: isMissing
  isPresent: isPresent
  isBlank: isBlank
  presence: presence
  isObject: isObject
  isFunction: isFunction
  isString: isString
  isBoolean: isBoolean
  isNumber: isNumber
  isElement: isElement
  isJQuery: isJQuery
  isElementish: isElementish
  isPromise: isPromise
  isOptions: isOptions
  isArray: isArray
  isFormData: isFormData
  isNodeList: isNodeList
  isArguments: isArguments
  isList: isList
  isRegExp: isRegExp
  timer: scheduleTimer
  contains: contains
  objectContains: objectContains
  toArray: toArray
  pick: pick
  pickBy: pickBy
  omit: omit
  unresolvablePromise: unresolvablePromise
  remove: remove
  memoize: memoize
  pluckKey: pluckKey
  renameKey: renameKey
  extractOptions: extractOptions
  extractCallback: extractCallback
  noop: noop
  asyncNoop: asyncNoop
  identity: identity
  escapeHTML: escapeHTML
  escapeRegExp: escapeRegExp
  sequence: sequence
  # previewable: previewable
  # parsePath: parsePath
  evalOption: evalOption
  # horizontalScreenHalf: horizontalScreenHalf
  flatten: flatten
  # flattenObject: flattenObject
  isTruthy: isTruthy
  newDeferred: newDeferred
  always: always
  # mutedFinally: mutedFinally
  muteRejection: muteRejection
  # rejectOnError: rejectOnError
  asyncify: asyncify
  isBasicObjectProperty: isBasicObjectProperty
  isCrossOrigin: isCrossOrigin
  task: queueTask
  microtask: queueMicrotask
  abortableMicrotask: abortableMicrotask
  isEqual: isEqual
  splitValues : splitValues
  endsWith: endsWith
  # sum: sum
  # wrapArray: wrapArray
  wrapList: wrapList
  wrapValue: wrapValue
  simpleEase: simpleEase
  values: objectValues
  # partial: partial
  # partialRight: partialRight
  arrayToSet: arrayToSet
  setToArray: setToArray
  # unprefixKeys: unprefixKeys
  uid: uid
  upperCaseFirst: upperCaseFirst
  lowerCaseFirst: lowerCaseFirst
  getter: defineGetter
  delegate: defineDelegates
  literal: literal
  # asyncWrap: asyncWrap
  reverse: reverse
  prefixCamelCase: prefixCamelCase
  unprefixCamelCase: unprefixCamelCase
  camelToKebabCase: camelToKebabCase
  nullToUndefined: nullToUndefined
  sprintf: sprintf
  sprintfWithFormattedArgs: sprintfWithFormattedArgs
  renameKeys: renameKeys
  timestamp: secondsSinceEpoch
  allSettled: allSettled
