###
# Copyright (C) 2014-2016 Taiga Agile LLC <taiga@taiga.io>
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
# File: lb-contact-team.controller.coffee
###

class ContactTeamLbController
    @.$inject = [
        "lightboxService",
        "tgResources",
        "$tgConfirm",
    ]

    constructor: (@lightboxService, @rs, @confirm)->
        @.contact = {}

    contactTeam: () ->
        if @.contact.message
            project = @.project.get('id')
            message = @.contact.message

            promise = @rs.projects.contactProject(project, message)
            @.sendingFeedback = true
            promise.then  =>
                @lightboxService.closeAll()
                @.sendingFeedback = false
                @confirm.notify("success")

angular.module("taigaProjects").controller("ContactTeamLbCtrl", ContactTeamLbController)
