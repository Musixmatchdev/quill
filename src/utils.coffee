#= underscore

TandemUtils = 
  removeHtmlWhitespace: (html) ->
    html.replace(/^\s\s*/, '').replace(/\s\s*$/, '').replace(/>\s\s+</gi, '><')

  Attribute:
    getTagName: (attribute) ->
      switch (attribute)
        when 'bold'       then return 'B'
        when 'italic'     then return 'I'
        when 'strike'     then return 'S'
        when 'underline'  then return 'U'
        else return 'SPAN'

  Input:
    normalizePosition: (editor, index) ->
      if _.isNumber(index)
        position = new Tandem.Position(editor, index)
      else if index instanceof Tandem.Range
        position = index.start
        index = position.getIndex()
      else
        position = index
        index = position.getIndex()
      return [position, index]


  Node:
    combineLines: (line1, line2) ->
      children = _.clone(line2.childNodes)
      _.each(children, (child) ->
        line1.appendChild(child)
      )
      line2.parentNode.removeChild(line2)

    createContainerForAttribute: (doc, attribute) ->
      switch (attribute)
        when 'bold'       then return doc.createElement('b')
        when 'italic'     then return doc.createElement('i')
        when 'strike'     then return doc.createElement('s')
        when 'underline'  then return doc.createElement('u')
        else                   return doc.createElement('span')

    extract: (editor, startIndex, endIndex) ->
      [startLine, startOffset] = Tandem.Utils.Node.getChildAtOffset(editor.iframeDoc.body, startIndex)
      [endLine, endOffset] = Tandem.Utils.Node.getChildAtOffset(editor.iframeDoc.body, endIndex)
      [leftStart, rightStart] = Tandem.Utils.Node.split(startLine, startOffset, true)
      if startLine == endLine
        endLine = rightStart
        endOffset -= leftStart.textContent.length if leftStart? && startLine != rightStart
      [leftEnd, rightEnd] = Tandem.Utils.Node.split(endLine, endOffset, true)
    
      fragment = editor.iframeDoc.createDocumentFragment()
      while rightStart != rightEnd
        next = rightStart.nextSibling
        fragment.appendChild(rightStart)
        rightStart = next    

      Tandem.Utils.Node.combineLines(leftStart, rightEnd) if leftStart? && rightEnd?

      return fragment

    getAncestorAttribute: (node, attribute, includeSelf = true) ->
      tagName = TandemUtils.Attribute.getTagName(attribute)
      ancestors = Tandem.Utils.Node.getAncestorNodes(node, (node) -> 
        return node.tagName == tagName
      , includeSelf)
      return if ancestors.length > 0 then ancestors[ancestors.length - 1] else null

    getAncestorNodes: (node, atRoot = TandemUtils.Node.isLine, includeSelf = true) ->
      ancestors = []
      ancestors.push(node) if includeSelf && atRoot(node)
      while node? && !atRoot(node)
        ancestors.push(node)
        node = node.parentNode
      ancestors.push(node)
      return if node? then ancestors else []

    getAttributes: (node) ->
      return _.reduce(TandemUtils.Node.getAncestorNodes(node), (attributes, ancestor) ->
        switch ancestor.tagName
          when 'B' then attributes['bold'] = true
          when 'I' then attributes['italic'] = true
          when 'S' then attributes['strike'] = true
          when 'U' then attributes['underline'] = true
        return attributes
      , {})

    getChildAtOffset: (node, offset) ->
      child = node.firstChild
      while offset > child.textContent.length
        offset -= child.textContent.length
        offset -= 1 if child.className == 'line'
        child = child.nextSibling
      return [child, offset]

    getLine: (node) ->
      ancestors = TandemUtils.Node.getAncestorNodes(node)
      return if ancestors.length > 0 then ancestors[ancestors.length - 1] else null

    getSiblings: (node, previous = true) ->
      sibling = if previous 'previousSibling' else 'nextSibling'
      siblings = []
      while node[sibling]?
        node = node[sibling]
        siblings.push(node)
      return siblings

    getPreviousSiblings: (node) ->
      return TandemUtils.Node.getSiblings(node, true)

    getNextSiblings: (node) ->
      return TandemUtils.Node.getSiblings(node, true)
      
    isLine: (node) ->
      return node.className == 'line'

    isTextNodeParent: (node) ->
      return node.childNodes.length == 1 && node.firstChild.nodeType == node.TEXT_NODE

    removeKeepingChildren: (doc, node) ->
      children = _.clone(node.childNodes)
      if _.all(children, (child) -> child.firstChild == null)
        span = doc.createElement('span')
        _.each(children, (child) ->
          span.appendChild(child)
        )
        children = [span]
      _.each(children, (child) ->
        node.parentNode.insertBefore(child, node)
      )
      node.parentNode.removeChild(node)

    split: (node, offset, force = false) ->
      if offset > node.textContent.length
        throw new Error('Splitting at offset greater than node length')

      # Check if split necessary
      if !force
        if offset == 0
          return [node.previousSibling, node]
        if offset == node.textContent.length
          return [node, node.nextSibling]

      left = node
      right = node.cloneNode(false)
      node.parentNode.insertBefore(right, left.nextSibling)

      if TandemUtils.Node.isTextNodeParent(node)
        # Text split
        beforeText = node.textContent.substring(0, offset)
        afterText = node.textContent.substring(offset)
        left.textContent = beforeText
        right.textContent = afterText
        return [left, right]
      else
        # Node split
        [child, offset] = TandemUtils.Node.getChildAtOffset(node, offset)
        [childLeft, childRight] = TandemUtils.Node.split(child, offset)
        while childRight != null
          nextRight = childRight.nextSibling
          right.appendChild(childRight)
          childRight = nextRight
        return [left, right]

    wrap: (wrapper, node) ->
      node.parentNode.insertBefore(wrapper, node)
      wrapper.appendChild(node)



window.Tandem ||= {}
window.Tandem.Utils = TandemUtils