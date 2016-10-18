###
# Copyright (C) 2014-2016 Andrey Antukh <niwi@niwi.nz>
# Copyright (C) 2014-2016 Jesús Espino Garcia <jespinog@gmail.com>
# Copyright (C) 2014-2016 David Barragán Merino <bameda@dbarragan.com>
# Copyright (C) 2014-2016 Alejandro Alonso <alejandro.alonso@kaleidos.net>
# Copyright (C) 2014-2016 Juan Francisco Alcántara <juanfran.alcantara@kaleidos.net>
# Copyright (C) 2014-2016 Xavi Julian <xavier.julian@kaleidos.net>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# File: modules/common/wysiwyg.coffee
###

taiga = @.taiga
bindOnce = @.taiga.bindOnce

module = angular.module("taigaCommon")

lans = "markup,css,clike,javascript,abap,actionscript,ada,apacheconf,apl,applescript,asciidoc,aspnet,autoit,autohotkey,bash,basic,batch,bison,brainfuck,bro,c,csharp,cpp,coffeescript,crystal,css-extras,d,dart,diff,docker,eiffel,elixir,erlang,fsharp,fortran,gherkin,git,glsl,go,graphql,groovy,haml,handlebars,haskell,haxe,http,icon,inform7,ini,j,jade,java,json,julia,keyman,kotlin,latex,less,livescript,lolcode,lua,makefile,markdown,matlab,mel,mizar,monkey,nasm,nginx,nim,nix,nsis,objectivec,ocaml,oz,parigp,parser,pascal,perl,php,php-extras,powershell,processing,prolog,properties,protobuf,puppet,pure,python,q,qore,r,jsx,rest,rip,roboconf,ruby,rust,sas,sass,scss,scala,scheme,smalltalk,smarty,sql,stylus,swift,tcl,textile,twig,typescript,verilog,vhdl,vim,wiki,xojo,yaml"
lans = lans.split(",")

# showdown extension
# -> input markdown
# a
# b
# c
# -> output html
# <p>a</br>
# b</br>
# c</p>
showdown.extension 'newline', () ->
    return [{
      type: 'lang',
      filter: (text) ->
          return text.replace /^( *(\d+\.  {1,4}|[\w\<\'\">\-*+])[^\n]*)\n{1}(?!\n| *\d+\. {1,4}| *[-*+] +|#|$)/gm, (e) ->
              return e.trim() + "  \n"
    }]

# MediumEditor extension to add <code>
CodeButton = MediumEditor.Extension.extend({
    name: 'code',
    init: () ->
        this.button = this.document.createElement('button')
        this.button.classList.add('medium-editor-action')
        this.button.innerHTML = '<b>Code</b>'
        this.button.title = 'Code'
        this.on(this.button, 'click', this.handleClick.bind(this))

    getButton: () ->
        return this.button

    handleClick: (event) ->
        range = MediumEditor.selection.getSelectionRange(self.document)

        if range.endContainer.parentNode.tagName != 'CODE'
            pre = document.createElement('pre');
            code = document.createElement('code');

            pre.appendChild(code)
            code.appendChild(range.extractContents())
            range.insertNode(pre)

            this.base.checkContentChanged()

        addCodeLanguageSelectors()
})

removeCodeLanguageSelectors = (mediumInstance) ->
    return
    $(mediumInstance.elements[0]).find('code').each (index, code) ->
        tab = $(code)
            .removeClass('has-code-language-selector')
            .data('tab')

        $(tab).remove()

getCodeLanHTML = (filter = '') ->
    template = _.template("""
    <% _.forEach(lans, function(lan) { %>
      <li><%- lan %></li><% });
    %>
    """);

    filteresLans = lans

    if filter.length
        filteresLans = _.filter filteresLans, (it) ->
            return it.indexOf(filter) != -1

    return template({ 'lans': filteresLans });

searchLanguage = (tab, cb) ->
    search = document.createElement('div')

    search.className = 'code-language-search'

    preRects = tab.getBoundingClientRect()
    search.style.top = (preRects.top + $(window).scrollTop() + preRects.height) + 'px'
    search.style.left = preRects.left + 'px'

    input = document.createElement('input')
    input.setAttribute('type', 'text')

    ul = document.createElement('ul')

    ul.innerHTML = getCodeLanHTML()

    search.appendChild(input)
    search.appendChild(ul)

    document.body.appendChild(search)

    input.focus()

    input.addEventListener 'keyup', (e) ->
        filter = e.currentTarget.value

        ul.innerHTML = getCodeLanHTML(filter)

    $(ul).on "click", "li", (e) ->
        cb(e.currentTarget.innerText)
        search.remove()

positionCodeTab = (node, tab) ->
    preRects = node.getBoundingClientRect()

    tab.style.top = (preRects.top + $(window).scrollTop()) + 'px'
    tab.style.left = (preRects.left + preRects.width - tab.offsetWidth) + 'px'

addCodeLanguageSelectors = (mediumInstance) ->
    $('code').each (index, code) ->
        if !$(code).hasClass('has-code-language-selector')
            $(code).addClass('has-code-language-selector')

            preRects = code.parentElement.getBoundingClientRect()

            text = document.createTextNode('text')

            tab = document.createElement('div')
            tab.appendChild(text)
            tab.addEventListener 'click', () ->
                searchLanguage tab, (lan) ->
                    tab.innerText = lan
                    positionCodeTab(code.parentElement, tab)
                    code.className = 'has-code-language-selector language-' + lan + ' ' + lan

            document.body.appendChild(tab)

            $(code).data('tab', tab)

            tab.className = 'code-language-selector'

            positionCodeTab(code.parentElement, tab)

class WysiwigService
    searchEmojiByName: (name) ->
        return _.filter @.emojis, (it) -> it.name.indexOf(name) != -1

    setEmojiImagePath: (emojis) ->
        @.emojis = _.map emojis, (it) ->
            it.image = "/#{window._version}/emojis/" + it.image

            return it

    loadEmojis: () ->
        $.getJSON("/#{window._version}/emojis/emojis-data.json").then(@.setEmojiImagePath.bind(this))

    getEmojiById: (id) ->
        return _.find  @.emojis, (it) -> it.id == id

    getEmojiByName: (name) ->
        return _.find @.emojis, (it) -> it.name == name

    replaceImgsByEmojiName: (html) ->
        emojiIds = taiga.getMatches(html, /emojis\/([^"]+).png"/gi)

        for emojiId in emojiIds
            regexImgs = new RegExp('<img(.*)' + emojiId + '[^>]+\>', 'g')
            emoji = @.getEmojiById(emojiId)
            html = html.replace(regexImgs, ':' + emoji.name + ':')

        return html

    replaceEmojiNameByImgs: (text) ->
        emojiIds = taiga.getMatches(text, /:([^: ]*):/g)

        for emojiId in emojiIds
            regexImgs = new RegExp(':' + emojiId + ':', 'g')
            emoji = @.getEmojiByName(emojiId)

            if emoji
                text = text.replace(regexImgs, '![alt](' + emoji.image + ')')

        return text

    getMarkdown: (html) ->
        # https://github.com/yabwe/medium-editor/issues/543
        cleanIssueConverter = {
            filter: ['html', 'body', 'span', 'div'],
            replacement: (innerHTML) ->
                return innerHTML
        }

        codeLanguageConverter = {
            filter:  (node) ->
                return node.nodeName == 'PRE' &&
                  node.firstChild &&
                  node.firstChild.nodeName == 'CODE'
            replacement: (content, node) ->
                lan = _.find node.firstChild.classList, (className) ->
                     return lans.indexOf(className) != -1

                lan = '' if !lan

                return '\n\n```' + lan + '\n' + node.firstChild.textContent + '\n```\n\n'
         }

        html = html.replace(/&nbsp;(<\/.*>)/g, "$1")

        html = @.replaceImgsByEmojiName(html)

        makdown = toMarkdown(html, {
            gfm: true,
            converters: [cleanIssueConverter, codeLanguageConverter]
        })

        console.log makdown

        return makdown

    getHTML: (text) ->
        return "" if !text || !text.length

        converter = new showdown.Converter({ extensions: ['newline'] })
        converter.setOption("strikethrough", true)

        text = @.replaceEmojiNameByImgs(text)

        html = converter.makeHtml(text)

        html = html.replace("<strong>", "<b>").replace("</strong>", "</b>")
        html = html.replace("<em>", "<i>").replace("</em>", "</i>")

        return html

module.service("tgWysiwigService", WysiwigService)


Medium = ($translate, $confirm, $storage, $rs, projectService, $navurls, wysiwigService) ->
    link = ($scope, $el, $attrs) ->
        mediumInstance = null
        editorMedium = $el.find('.medium')
        editorMarkdown = $el.find('.markdown')

        languages = []

        isEditOnly = !!$attrs.$attr.editonly
        notPersist = !!$attrs.$attr.notPersist

        $scope.required = !!$attrs.$attr.required

        $scope.editMode = isEditOnly || false

        $scope.mode = $storage.get('editor-mode', 'html')

        wysiwigService.loadEmojis()

        $.getJSON("/#{window._version}/prism/prism-languages.json").then (languages) ->
            languages = _.map languages, (it) ->
                languages.url = "/#{window._version}/prism/" + it.file

                return it

        $scope.setMode = (mode) ->
            $storage.set('editor-mode', mode)

            if mode == 'markdown'
                 $scope.markdown = wysiwigService.getMarkdown(editorMedium.html())
            else
                html = wysiwigService.getHTML($scope.markdown)
                editorMedium.html(html)

            $scope.mode = mode
            mediumInstance.trigger('editableBlur', {}, editorMedium[0])

        $scope.save = () ->
            if $scope.mode == 'html'
                $scope.markdown = wysiwigService.getMarkdown(editorMedium.html())

            return if $scope.required && !$scope.markdown.length

            $scope.saving  = true
            $scope.outdated = false

            $scope.onSave({text: $scope.markdown, cb: saveEnd})

            return

        $scope.cancel = () ->
            if !isEditOnly
                $scope.editMode = false

            if notPersist
                clean()
            else if $scope.mode == 'html'
                html = wysiwigService.getHTML($scope.content)
                editorMedium.html(html)
            else
                $scope.markdown = $scope.content

            discardLocalStorage()
            mediumInstance.trigger('blur', {}, editorMedium[0])
            $scope.outdated = false

            $scope.onCancel()

            return

        clean = () ->
            $scope.markdown = ''
            editorMedium.html('')

        saveEnd = () ->
            $scope.saving  = false

            if !isEditOnly
                $scope.editMode = false

            if notPersist
                clean()

            discardLocalStorage()
            mediumInstance.trigger('blur', {}, editorMedium[0])

        uploadEnd = (name, url) ->
            if taiga.isImage(name)
                mediumInstance.pasteHTML("<img src='" + url + "' /><br/>")
            else
                name = $('<div/>').text(name).html()
                mediumInstance.pasteHTML("<a target='_blank' href='" + url + "'>" + name + "</a><br/>")

        isOutdated = () ->
            store = $storage.get($scope.storageKey)

            if store && store.version && store.version != $scope.version
                return true

            return false

        isDraft = () ->
            store = $storage.get($scope.storageKey)

            if store
                return true

            return false

        getCurrentContent = () ->
            store = $storage.get($scope.storageKey)

            if store
                return store.text

            return $scope.content

        discardLocalStorage = () ->
            $storage.remove($scope.storageKey)

        cancelWithConfirmation = () ->
            title = $translate.instant("COMMON.CONFIRM_CLOSE_EDIT_MODE_TITLE")
            message = $translate.instant("COMMON.CONFIRM_CLOSE_EDIT_MODE_MESSAGE")

            $confirm.ask(title, null, message).then (askResponse) ->
                $scope.cancel()
                askResponse.finish()

        localSave = (markdown) ->
            if $scope.storageKey
                store = {}
                store.version = $scope.version || 0
                store.text = markdown
                $storage.set($scope.storageKey, store)

        change = () ->
            if $scope.mode == 'html'
                $scope.markdown = wysiwigService.getMarkdown(editorMedium.html())

            localSave($scope.markdown)

            $scope.onChange({markdown: $scope.markdown})

        cancelablePromise = null

        searchEmoji = (name, cb) ->
            filteredEmojis = wysiwigService.searchEmojiByName(name)
            filteredEmojis = filteredEmojis.slice(0, 10)

            cb(filteredEmojis)

        searchUser = (term, cb) ->
            searchProps = ['username', 'full_name', 'full_name_display']

            users = projectService.project.toJS().members.filter (user) =>
                for prop in searchProps
                    if taiga.slugify(user[prop]).indexOf(term) >= 0
                        return true
                return false

             users = users.slice(0, 10).map (it) ->
                it.url = $navurls.resolve('user-profile', {
                    project: projectService.project.get('slug'),
                    username: it.username
                })

                return it

            cb(users)

        searchItem = (term) ->
            return new Promise (resolve, reject) ->
                term = taiga.slugify(term)

                searchTypes = ['issues', 'tasks', 'userstories']
                urls = {
                    issues: "project-issues-detail",
                    tasks: "project-tasks-detail",
                    userstories: "project-userstories-detail"
                }
                searchProps = ['ref', 'subject']

                filter = (item) =>
                    for prop in searchProps
                        if taiga.slugify(item[prop]).indexOf(term) >= 0
                            return true
                    return false

                cancelablePromise.abort() if cancelablePromise

                cancelablePromise = $rs.search.do(projectService.project.get('id'), term)

                cancelablePromise.then (res) =>
                    # ignore wikipages if they're the only results. can't exclude them in search
                    if res.count < 1 or res.count == res.wikipages.length
                        resolve([])
                    else
                        result = []
                        for type in searchTypes
                            if res[type] and res[type].length > 0
                                items = res[type].filter(filter)
                                items = items.map (it) ->
                                    it.url = $navurls.resolve(urls[type], {
                                        project: projectService.project.get('slug'),
                                        ref: it.ref
                                    })

                                    return it

                                result = result.concat(items)

                        resolve(result.slice(0, 10))

        throttleChange = _.throttle(change, 1000)

        create = (text, editMode=false) ->
            if text.length
                html = wysiwigService.getHTML(text)
                editorMedium.html(html)

            mediumInstance = new MediumEditor(editorMedium[0], {
                targetBlank: true,
                autoLink: true,
                imageDragging: false,
                placeholder: {
                    text: $scope.placeholder
                },
                toolbar: {
                    buttons: [
                        'bold',
                        'italic',
                        'strikethrough',
                        'anchor',
                        'image',
                        'orderedlist',
                        'unorderedlist',
                        'h1',
                        'h2',
                        'h3',
                        'quote',
                        'code'
                    ]
                },
                extensions: {
                    code: new CodeButton(),
                    autolist: new AutoList(),
                    mediumMention: new MentionExtension({
                        getItems: (mention, mentionCb) ->
                            if '#'.indexOf(mention[0]) != -1
                                searchItem(mention.replace('#', '')).then(mentionCb)
                            else if '@'.indexOf(mention[0]) != -1
                                searchUser(mention.replace('@', ''), mentionCb)
                            else if ':'.indexOf(mention[0]) != -1
                                searchEmoji(mention.replace(':', ''), mentionCb)
                    })
                }
            })

            $scope.changeMarkdown = throttleChange

            mediumInstance.subscribe 'editableInput', (e) ->
                $scope.$applyAsync(throttleChange)

            mediumInstance.subscribe "editableClick", (e) ->
                e.stopPropagation()

                if e.target.href
                    window.open(e.target.href)

            mediumInstance.subscribe 'focus', (event) ->
                $scope.$applyAsync () -> $scope.editMode = true
                addCodeLanguageSelectors()

            mediumInstance.subscribe 'editableDrop', (event) ->
                $scope.onUploadFile({files: event.dataTransfer.files, cb: uploadEnd})

            mediumInstance.subscribe 'editableKeydown', (e) ->
                code = if e.keyCode then e.keyCode else e.which

                mention = $('.medium-mention')

                if (code == 40 || code == 38) && mention.length
                    e.stopPropagation()
                    e.preventDefault()

                    return

                if $scope.editMode && code == 27
                    e.stopPropagation()
                    $scope.$applyAsync(cancelWithConfirmation)
                else if code == 27
                    editorMedium.blur()

            $scope.editMode = editMode

        # $scope.$watch 'editMode', (editMode) ->
        #     if editMode
        #         addCodeLanguageSelectors(mediumInstance)

        $scope.$watch 'content', (content) ->
            if !_.isUndefined(content)
                $scope.outdated = isOutdated()

                if !mediumInstance && isDraft()
                    $scope.editMode = true

                if $scope.markdown == content
                    return

                content = getCurrentContent()

                $scope.markdown = content

                if mediumInstance
                    mediumInstance.destroy()

                create(content, $scope.editMode)

        $scope.$on "$destroy", () ->
            if mediumInstance
                mediumInstance.destroy()

    return {
        templateUrl: "common/components/wysiwyg-toolbar.html",
        scope: {
            placeholder: '@',
            version: '<',
            storageKey: '<',
            content: '<',
            onCancel: '&',
            onSave: '&',
            onUploadFile: '&',
            onChange: '&'
        },
        link: link
    }

module.directive("tgMedium", [
    "$translate",
    "$tgConfirm",
    "$tgStorage",
    "$tgResources",
    "tgProjectService",
    "$tgNavUrls",
    "tgWysiwigService",
    Medium
])
