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
# File: modules/common/wysiwyg/wysiwyg.coffee
###

taiga = @.taiga
bindOnce = @.taiga.bindOnce

Medium = ($translate, $confirm, $storage, $rs, projectService, $navurls, wysiwigService, animationFrame, tgLoader, wysiwygCodeHightlighterService) ->
    # MediumEditor extension to add <code>
    CodeButton = MediumEditor.extensions.button.extend({
        name: 'code',
        init: () ->
            this.button = this.document.createElement('button')
            this.button.classList.add('medium-editor-action')
            this.button.innerHTML = '<b>Code</b>'
            this.button.title = 'Code'
            this.on(this.button, 'click', this.handleClick.bind(this))

        getButton: () ->
            return this.button

        tagNames: ['code']

        handleClick: (event) ->
            range = MediumEditor.selection.getSelectionRange(self.document)

            if range.endContainer.parentNode.tagName != 'CODE'
                pre = document.createElement('pre');
                code = document.createElement('code');

                pre.appendChild(code)
                code.appendChild(range.extractContents())
                range.insertNode(pre)

                this.base.checkContentChanged()

            wysiwygCodeHightlighterService.addCodeLanguageSelectors(this.base)
    })

    # bug
    # <pre><code></code></pre> the enter doesn't work
    oldIsBlockContainer = MediumEditor.util.isBlockContainer

    MediumEditor.util.isBlockContainer = (element) ->
        if element.tagName.toLowerCase() == 'code'
            return true

        return oldIsBlockContainer(element)

    link = ($scope, $el, $attrs) ->
        mediumInstance = null
        editorMedium = $el.find('.medium')
        editorMarkdown = $el.find('.markdown')

        isEditOnly = !!$attrs.$attr.editonly
        notPersist = !!$attrs.$attr.notPersist

        $scope.required = !!$attrs.$attr.required

        $scope.editMode = isEditOnly || false

        $scope.mode = $storage.get('editor-mode', 'html')

        wysiwigService.loadEmojis()

        setHtmlMedium = (markdown) ->
            html = wysiwigService.getHTML(markdown)
            editorMedium.html(html)

        $scope.setMode = (mode) ->
            $storage.set('editor-mode', mode)

            if mode == 'markdown'
                $scope.markdown = wysiwigService.getMarkdown(editorMedium.html())
            else
                setHtmlMedium($scope.markdown)

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
                setHtmlMedium($scope.content)
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

        refreshExtras = () ->
            animationFrame.add () ->
                if $scope.mode == 'html'
                    if $scope.editMode
                        wysiwygCodeHightlighterService.addCodeLanguageSelectors(mediumInstance)
                        wysiwygCodeHightlighterService.removeHightlighter(mediumInstance)
                    else
                        wysiwygCodeHightlighterService.addHightlighter(mediumInstance)
                        wysiwygCodeHightlighterService.removeCodeLanguageSelectors(mediumInstance)
                else
                    wysiwygCodeHightlighterService.removeHightlighter(mediumInstance)
                    wysiwygCodeHightlighterService.removeCodeLanguageSelectors(mediumInstance)

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
                wysiwygCodeHightlighterService.updateCodeLanguageSelector(mediumInstance)

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

        throttleChange = _.throttle(change, 200)

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
                $scope.$applyAsync () ->
                    if !$scope.editMode
                        $scope.editMode = true

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

            $scope.$applyAsync(refreshExtras)

            $scope.$watch () ->
                return $scope.mode + ":" + $scope.editMode
            , (xxx) ->
                $scope.$applyAsync(refreshExtras)

        unwatch = $scope.$watch 'content', (content) ->
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

                if tgLoader.open()
                    unwatchLoader = tgLoader.onEnd () ->
                        create(content, $scope.editMode)
                        unwatchLoader()
                else
                    create(content, $scope.editMode)

                unwatch()

        $scope.$on "$destroy", () ->
            if mediumInstance
                removeCodeLanguageSelectors(mediumInstance)
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

angular.module("taigaComponents").directive("tgWysiwyg", [
    "$translate",
    "$tgConfirm",
    "$tgStorage",
    "$tgResources",
    "tgProjectService",
    "$tgNavUrls",
    "tgWysiwigService",
    "animationFrame",
    "tgLoader",
    "tgWysiwygCodeHightlighterService",
    Medium
])
