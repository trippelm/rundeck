%{--
  - Copyright 2016 SimplifyOps, Inc. (http://simplifyops.com)
  -
  - Licensed under the Apache License, Version 2.0 (the "License");
  - you may not use this file except in compliance with the License.
  - You may obtain a copy of the License at
  -
  -     http://www.apache.org/licenses/LICENSE-2.0
  -
  - Unless required by applicable law or agreed to in writing, software
  - distributed under the License is distributed on an "AS IS" BASIS,
  - WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  - See the License for the specific language governing permissions and
  - limitations under the License.
  --}%

<%@ page import="grails.util.Environment" %>
<html>
<head>
    <g:set var="rkey" value="${g.rkey()}" />
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
    <meta name="layout" content="base"/>
    <meta name="tabpage" content="jobs"/>
    <title><g:message code="gui.menu.Workflows"/> - <g:enc>${params.project ?: request.project}</g:enc></title>
    <g:javascript library="yellowfade"/>
    <g:javascript library="pagehistory"/>
    <g:javascript library="prototype/effects"/>
    <asset:javascript src="menu/jobs.js"/>
    <asset:javascript src="jquery.autocomplete.min.js"/>
    <g:if test="${grails.util.Environment.current==grails.util.Environment.DEVELOPMENT}">
        <asset:javascript src="menu/joboptionsTest.js"/>
        <asset:javascript src="menu/job-remote-optionsTest.js"/>
    </g:if>
    <g:embedJSON id="pageParams" data="${[project:params.project?:request.project]}"/>
    <g:embedJSON data="${projectNames ?: []}" id="projectNamesData"/>
    <g:jsMessages code="Node,Node.plural,job.starting.execution,job.scheduling.execution,option.value.required,options.remote.dependency.missing.required,,option.default.button.title,option.default.button.text,option.select.choose.text"/>
    <!--[if (gt IE 8)|!(IE)]><!--> <g:javascript library="ace/ace"/><!--<![endif]-->
    <script type="text/javascript">
        /** knockout binding for activity */
        var pageActivity;
        function showError(message){
             appendText($('error'),message);
             $("error").show();
        }
        var _jobExecUnloadHandlers=new Array();
        function _registerJobExecUnloadHandler(handler){
            _jobExecUnloadHandlers.push(handler);
        }
        function unloadExec(){
            if(_jobExecUnloadHandlers.length>0){
                for(var i =0;i<_jobExecUnloadHandlers.length;i++){
                    _jobExecUnloadHandlers[i].call();
                }
                _jobExecUnloadHandlers.clear();
            }

            jQuery('#execDiv').modal('hide');
            clearHtml('execDivContent');

            $('busy').hide();
        }
        function requestError(item,trans){
            unloadExec();
            showError("Failed request: "+item+" . Result: "+trans.getStatusText());
        }
        function loadExec(id,eparams) {
            $("error").hide();
            var params=eparams;
            if(!params){
                params={id:id};
            }
            jQuery('#execDivContent').load(_genUrl(appLinks.scheduledExecutionExecuteFragment, params),function(response,status,xhr){
                if (status == "success") {
                    loadedFormSuccess(!!id,id);
                } else {
                    requestError("executeFragment for [" + id + "]",xhr);
                }
            });
        }
        function execSubmit(elem, target) {
            var data = new FormData(jQuery('#' + elem + ' form')[0]);
            jQuery.ajax({
                url: target,
                type: 'POST',
                data: data,
                contentType: false,
                dataType: 'json',
                processData: false,
                success: function (result) {
                    if (result.id) {
                        if (result.follow && result.href) {
                            document.location = result.href;
                        } else {
                            if (!pageActivity.selected()) {
                                pageActivity.activateNowRunningTab();
                            }
                            unloadExec();
                        }
                    } else if (result.error === 'invalid') {
                        // reload form for validation
                        loadExec(null, Form.serialize(elem) + "&dovalidate=true");
                    } else {
                        unloadExec();
                        showError(result.message ? result.message : result.error ? result.error : "Failed request");
                    }
                },
                error: function (x) {
                    requestError("runJobInline", x);
                }
            });
        }
        function loadedFormSuccess(doShow,id){
            if ($('execFormCancelButton')) {
                Event.observe($('execFormCancelButton'),'click',function(evt) {
                    Event.stop(evt);
                    unloadExec();
                    return false;
                },false);
                $('execFormCancelButton').name = "_x";
            }
            if ($('execFormRunButton')) {
                Event.observe($('execFormRunButton'),'click', function(evt) {
                    Event.stop(evt);
                    execSubmit('execDivContent', appLinks.scheduledExecutionRunJobInline);
                    $('formbuttons').loading(message('job.starting.execution'));
                    return false;
                },false);
            }
            jQuery('#showScheduler').on('shown.bs.popover', function() {
                if ($('scheduleAjaxButton')) {
                    Event.observe($('scheduleAjaxButton'), 'click', function(evt) {
                        Event.stop(evt);
                        if (isValidDate()) {
                            toggleAlert(true);
		                    execSubmit('execDivContent',
                                appLinks.scheduledExecutionScheduleJobInline);
		                    $('formbuttons').loading(message('job.scheduling.execution'));
                        } else {
                            toggleAlert(false);
                        }
                        return false;
                    }, false);
                }
            });

            //setup option handling
            //setup option edit
            var joboptiondata = loadJsonData('jobOptionData');
            var joboptions = new JobOptions(joboptiondata);

            if (document.getElementById('optionSelect')) {
                ko.applyBindings(joboptions, document.getElementById('optionSelect'));
            }

            var remoteoptionloader = new RemoteOptionLoader({
                url: "${createLink(controller:'scheduledExecution',action:'loadRemoteOptionValues',params:[format:'json'])}",
                id:id,
                fieldPrefix: "extra.option."
            });
            var remotecontroller = new RemoteOptionController({
                loader: remoteoptionloader,
            });
            remotecontroller.setupOptions(joboptions);

            remotecontroller.loadData(loadJsonData('remoteOptionData'));
            if (typeof(_registerJobExecUnloadHandler) == 'function') {
                _registerJobExecUnloadHandler(remotecontroller.unsubscribeAll);
            }
            joboptions.remoteoptions = remotecontroller;
            remotecontroller.begin();

            jQuery('input').on('keydown', function (evt) {
                return noenter(evt);
            });
            if(doShow){
                jQuery('#execDiv').modal('show');
            }
            $('busy').hide();
        }

       


        //set box filterselections

        function _setFilterSuccess(data,name){
            if(data){
                var bfilters=data.filterpref;
                //reload page
                document.location=_genUrl(appLinks.menuJobs , bfilters[name] ? {filterName:bfilters[name]} : {});
            }
        }


        /** now running section update */
        function _pageUpdateNowRunning(count){
        }
        var lastRunExec=0;
        /**
         * Handle embedded content updates
         */
        function _updateBoxInfo(name,data){
            if(name==='events' && data.lastDate){
                histControl.setHiliteSince(data.lastDate);
            }
            if (name == 'nowrunning' && data.lastExecId && data.lastExecId != lastRunExec) {
                lastRunExec = data.lastExecId;
            }
        }

        /////////////
        // Job context detail popup code
        /////////////

        var doshow=false;
        var popvis=false;
        var lastHref;
        var targetLink;
        function popJobDetails(elem){
            if(doshow && $('jobIdDetailHolder')){
                new MenuController().showRelativeTo(elem,$('jobIdDetailHolder'));
                popvis=true;
                if(targetLink){
                    $(targetLink).removeClassName('glow');
                    targetLink=null;
                }
                $(elem).addClassName('glow');
                targetLink=elem;
            }
        }
        var motimer;
        var mltimer;
        function bubbleMouseover(evt){
            if(mltimer){
                clearTimeout(mltimer);
                mltimer=null;
            }
        }
        function jobLinkMouseover(elem,evt){
            if(mltimer){
                clearTimeout(mltimer);
                mltimer=null;
            }
            if(motimer){
                clearTimeout(motimer);
                motimer=null;
            }
            if(popvis && lastHref===elem.href){
                return;
            }
            var delay=1500;
            if(popvis){
                delay=0;
            }
            motimer=setTimeout(showJobDetails.curry(elem),delay);
        }
        function doMouseout(){
            if(popvis && $('jobIdDetailHolder')){
                popvis=false;
                Try.these(
                    function(){
                        jQuery('#jobIdDetailHolder').fadeOut('fast');
                    },
                    function(){$('jobIdDetailHolder').hide();}
                    );
            }
            if(targetLink){
                $(targetLink).removeClassName('glow');
                targetLink=null;
            }
        }
        function jobLinkMouseout(elem,evt){
            //hide job details
            if(motimer){
                clearTimeout(motimer);
                motimer=null;
            }
            doshow=false;
            mltimer=setTimeout(doMouseout,0);
        }
        function showJobDetails(elem){
            //get url
            var href=elem.href || elem.getAttribute('data-href');
            lastHref=href;
            doshow=true;
            //match is id
            var matchId = jQuery(elem).data('jobId');
            if(!matchId){
                return;
            }
            var viewdom=$('jobIdDetailHolder');
            var bcontent=$('jobIdDetailContent');
            if(viewdom){
                viewdom.parentNode.removeChild(viewdom);
                viewdom=null;
            }
            if(!viewdom){
                viewdom = $(document.createElement('div'));
                viewdom.addClassName('bubblewrap');
                viewdom.setAttribute('id','jobIdDetailHolder');
                viewdom.setAttribute('style','display:none;width:600px;height:250px;');

                Event.observe(viewdom,'click',function(evt){
                    evt.stopPropagation();
                },false);

                var btop = new Element('div');
                btop.addClassName('bubbletop');
                viewdom.appendChild(btop);
                bcontent = new Element('div');
                bcontent.addClassName('bubblecontent');
                bcontent.setAttribute('id','jobIdDetailContent');
                viewdom.appendChild(bcontent);
                document.body.appendChild(viewdom);
                Event.observe(viewdom,'mouseover',bubbleMouseover);
                Event.observe(viewdom,'mouseout',jobLinkMouseout.curry(viewdom));
            }
            bcontent.loading();
            var jobNodeFilters;
            jQuery.ajax({
                dataType:'json',
                url:_genUrl(appLinks.scheduledExecutionDetailFragmentAjax, {id: matchId}),
                success:function(data,status,xhr){
                    var params={};
                    if(data.job && data.job.doNodeDispatch) {
                        if (data.job.filter) {
                            params.filter = data.job.filter;
                        }
                    }else{
                        params.localNodeOnly=true;
                        params.emptyMode='localnode';
                    }
                    jobNodeFilters=initJobNodeFilters(params);
                }
            }).done(
                    function(){
                        jQuery('#jobIdDetailContent').load(_genUrl(appLinks.scheduledExecutionDetailFragment, {id: matchId}),
                                function(response,status,xhr){
                            if (status=='success') {
                                var wrapDiv = jQuery('#jobIdDetailHolder').find('.ko-wrap')[0];
                                if(wrapDiv) {
                                    ko.applyBindings(jobNodeFilters, wrapDiv);
                                }
                                popJobDetails(elem);
                                $('jobIdDetailContent').select('.apply_ace').each(function (t) {
                                    _applyAce(t);
                                });
                            }else{
                                clearHtml(bcontent);
                                viewdom.hide();
                            }
                        });
                    }
            );

        }

        function initJobIdLinks(){
            $$('.hover_show_job_info').each(function(e){
                Event.observe(e,'mouseover',jobLinkMouseover.curry(e));
                Event.observe(e,'mouseout',jobLinkMouseout.curry(e));
            });

            jQuery('.act_job_action_dropdown').click(function(){
                var id=jQuery(this).data('jobId');
                var el=jQuery(this).parent().find('.dropdown-menu');
                el.load(
                    _genUrl(appLinks.scheduledExecutionActionMenuFragment,{id:id})
                );
            });
        }
         function filterToggle(evt) {
            ['${enc(js:rkey)}filter','${enc(js:rkey)}filter-toggle'].each(Element.toggle);
        }
        function filterToggleSave(evt) {
            ['${enc(js:rkey)}filter','${enc(js:rkey)}fsave'].each(Element.show);
            ['${enc(js:rkey)}filter-toggle','${enc(js:rkey)}fsavebtn'].each(Element.hide);
        }
        function init(){
            <g:if test="${!(grailsApplication.config.rundeck?.gui?.enableJobHoverInfo in ['false',false])}">
            initJobIdLinks();
            </g:if>

            PageActionHandlers.registerHandler('job_delete_single',function(el){
                bulkeditor.activateActionForJob(bulkeditor.DELETE,el.data('jobId'));
            });
            PageActionHandlers.registerHandler('enable_job_execution_single',function(el){
                bulkeditor.activateActionForJob(bulkeditor.ENABLE_EXECUTION,el.data('jobId'));
            });
            PageActionHandlers.registerHandler('disable_job_execution_single',function(el){
                bulkeditor.activateActionForJob(bulkeditor.DISABLE_EXECUTION,el.data('jobId'));
            });
            PageActionHandlers.registerHandler('disable_job_schedule_single',function(el){
                bulkeditor.activateActionForJob(bulkeditor.DISABLE_SCHEDULE,el.data('jobId'));
            });
            PageActionHandlers.registerHandler('enable_job_schedule_single',function(el){
                bulkeditor.activateActionForJob(bulkeditor.ENABLE_SCHEDULE,el.data('jobId'));
            });

            PageActionHandlers.registerHandler('copy_other_project',function(el){
                jQuery('#jobid').val(el.data('jobId'));
                jQuery('#selectProject').modal();
            });


            Event.observe(document.body,'click',function(evt){
                //click outside of popup bubble hides it
                doMouseout();
            },false);
            Event.observe(document,'keydown',function(evt){
                //escape key hides popup bubble
                if(evt.keyCode===27 ){
                    doMouseout();
                }
                return true;
            },false);

            $$('.obs_filtertoggle').each(function(e) {
                Event.observe(e, 'click', filterToggle);
            });
            $$('.obs_filtersave').each(function(e) {
                Event.observe(e, 'click', filterToggleSave);
            });
        }
        /**
         * Possible actions for bulk edit jobs, to present in modal dialog
         * @constructor
         */
        function BulkEditor(){
            var self=this;
            self.DISABLE_SCHEDULE = 'disable_schedule';
            self.ENABLE_SCHEDULE = 'enable_schedule';
            self.ENABLE_EXECUTION= 'enable_execution';
            self.DISABLE_EXECUTION= 'disable_execution';
            self.DELETE= 'delete';
            self.action=ko.observable(null);
            self.enabled=ko.observable(false);
            self.beginEdit=function(){
                self.expandAllComponents();
                self.enabled(true);
            };
            self.cancelEdit=function(){
                self.enabled(false);
                self.selectNone();
            };
            self.disableSchedule=function(){

                self.action(self.DISABLE_SCHEDULE);
            };
            self.isDisableSchedule=ko.pureComputed(function(){
                return self.action()===self.DISABLE_SCHEDULE;
            });
            self.enableSchedule=function(){
                self.action(self.ENABLE_SCHEDULE);
            };
            self.isEnableSchedule=ko.pureComputed(function(){
                return self.action()===self.ENABLE_SCHEDULE;
            });
            self.enableExecution=function(){
                self.action(self.ENABLE_EXECUTION);
            };
            self.isEnableExecution=ko.pureComputed(function(){
                return self.action()===self.ENABLE_EXECUTION;
            });
            self.disableExecution=function(){
                self.action(self.DISABLE_EXECUTION);
            };
            self.isDisableExecution=ko.pureComputed(function(){
                return self.action()===self.DISABLE_EXECUTION;
            });
            self.actionDelete=function(){
                self.action(self.DELETE);
            };
            self.isDelete=ko.pureComputed(function(){
                return self.action()===self.DELETE;
            });
            self.cancel=function(){
                self.action(null);
            };

            self.setCheckboxValues=function(ids){
                //check only the checkbox with this job id by passing an array
                jQuery('.jobbulkeditfield :input[name=ids]').val(ids);
            };
            self.checkboxesForGroup=function(group){
                return jQuery('.jobbulkeditfield input[type=checkbox][data-job-group="'+group+'"]');
            };
            self.allCheckboxes=function(group){
                return jQuery('.jobbulkeditfield input[type=checkbox]');
            };
            self.jobGroupSelectAll=function(e){
                var jgroup=jQuery(e).data('job-group');
                if(jgroup){
                    self.checkboxesForGroup(jgroup).prop('checked', true);
                }
            };

            self.jobGroupSelectNone=function(e){
                var jgroup=jQuery(e).data('job-group');
                if(jgroup){
                    self.checkboxesForGroup(jgroup).prop('checked', false);
                }
            };
            self.expandAllComponents=function(){
                jQuery('.expandComponent').show();
            };
            self.collapseAllComponents=function(){
                jQuery('.topgroup .expandComponent').hide();
            };
            self.selectAll=function(){
                self.expandAllComponents();
                self.allCheckboxes().prop('checked', true);
            };
            self.selectNone=function(){
                self.expandAllComponents();
                self.allCheckboxes().prop('checked', false);
            };
            self.toggleModal=function(){
                jQuery('#bulk_del_confirm').modal('toggle');
            };
            self.activateActionForJob=function(action,jobid){
                self.setCheckboxValues([jobid]);
                self.beginEdit();
                self.action(action);
                self.toggleModal();
            }
        }
        var bulkeditor;
        jQuery(document).ready(function () {
            init();
            if (jQuery('#activity_section')) {
                pageActivity = new History(appLinks.reportsEventsAjax, appLinks.menuNowrunningAjax);
                ko.applyBindings(pageActivity, document.getElementById('activity_section'));
                setupActivityLinks('activity_section', pageActivity);
            }
            jQuery(document).on('click','.act_execute_job',function(evt){
                evt.preventDefault();
               loadExec(jQuery(this).data('jobId'));
            });
            $$('#wffilterform input').each(function(elem){
                if(elem.type=='text'){
                    elem.observe('keypress',noenter);
                }
            });
            bulkeditor=new BulkEditor();
            ko.applyBindings(bulkeditor,document.getElementById('bulk_del_confirm'));
            ko.applyBindings(bulkeditor,document.getElementById('bulk_edit_panel'));
            ko.applyBindings(bulkeditor,document.getElementById('job_action_menu'));
            ko.applyBindings(bulkeditor,document.getElementById('job_group_tree'));
            ko.applyBindings(bulkeditor,document.getElementById('group_controls'));
        });
    </script>
    <g:javascript library="yellowfade"/>
    <asset:javascript src="menu/joboptions.js"/>
    <style type="text/css">
    .error{
        color:red;
    }

        #histcontent table{
            width:100%;
        }
    </style>
</head>
<body>


<g:if test="${flash.bulkJobResult?.errors}">
    <div class="alert alert-dismissable alert-warning">
        <a class="close" data-dismiss="alert" href="#" aria-hidden="true">&times;</a>
        <ul>
            <g:if test="${flash.bulkJobResult.errors instanceof org.springframework.validation.Errors}">
                <g:renderErrors bean="${flash.bulkJobResult.errors}" as="list"/>
            </g:if>
            <g:else>
                <g:each in="${flash.bulkJobResult.errors*.message}" var="message">
                    <li><g:autoLink>${message}</g:autoLink></li>
                </g:each>
            </g:else>
        </ul>
    </div>
</g:if>
<g:if test="${flash.bulkJobResult?.success}">
    <div class="alert alert-dismissable alert-info">
        <a class="close" data-dismiss="alert" href="#" aria-hidden="true">&times;</a>
        <ul>
        <g:each in="${flash.bulkJobResult.success*.message}" var="message">
            <li><g:autoLink>${message}</g:autoLink></li>
        </g:each>
        </ul>
    </div>
</g:if>
<div class="runbox primary jobs" id="indexMain">
    <div id="error" class="alert alert-danger" style="display:none;"></div>
    <g:render template="workflowsFull" model="${[jobExpandLevel:jobExpandLevel,jobgroups:jobgroups,wasfiltered:wasfiltered?true:false, clusterMap: clusterMap,nextExecutions:nextExecutions,jobauthorizations:jobauthorizations,authMap:authMap,nowrunningtotal:nowrunningtotal,max:max,offset:offset,paginateParams:paginateParams,sortEnabled:true,rkey:rkey]}"/>
</div>
<div class="modal fade" id="execDiv" role="dialog" aria-labelledby="deleteFilterModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header">
                <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
                <h4 class="modal-title" id="deleteFilterModalLabel"><g:message code="job.execute.action.button" /></h4>
            </div>

            <div class="" id="execDivContent">


            </div>
</div>
</div>
</div>

<div class="modal fade" id="selectProject" role="dialog" aria-labelledby="selectProjectLabel" aria-hidden="true">
    <div class="modal-dialog modal-sm">
        <div class="modal-content">
            <div class="modal-header">
                <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
                <h4 class="modal-title" id="selectProjectLabel"><g:message code="select.project" /></h4>
            </div>
            <g:form controller="scheduledExecution">
                <div class="modal-body" id="selectProjectContent">

                    <input type="hidden" id="jobid" name="id"/>
                    <input id="jobProject"  type="text" name="project" value="" size="100"
                                              placeholder="${message(code:"select.project")}"
                                              class="form-control"
                                       />
                    <g:javascript>
                    fireWhenReady('jobProject',function(){
                         var projectsArr = loadJsonData('projectNamesData');
                         jQuery("#jobProject").devbridgeAutocomplete({
                                     lookup: projectsArr
                         });
                        jQuery("#jobProject").on('keyup blur', function(){
                            jQuery('#submittbn').prop('disabled', this.value.trim().length == 0);
                        });
                     });
                    </g:javascript>
                </div>
                <div class="modal-footer">
                    <button type="button"
                            class="btn btn-danger"
                            data-bind="click: cancel"
                            data-dismiss="modal" ><g:message code="cancel"/></button>

                    <g:actionSubmit action="copy"
                                    value="${message(code:'yes')}"
                                    id="submittbn"
                                    disabled="disabled"
                                    class="btn btn-default"/>
                </div>
            </g:form>
        </div>
    </div>
</div>

<div class="row row-space" id="activity_section">
    <div class="col-sm-12 ">
        <h4 class="text-muted "><g:message code="page.section.Activity.for.jobs" /></h4>
        <g:render template="/reports/activityLinks"
                  model="[filter: [projFilter: params.project ?: request.project, jobIdFilter: '!null',], knockoutBinding: true, showTitle:true]"/>
    </div>
</div>
</body>
</html>
