<!DOCTYPE html>
<html>
<head>
<title><#Web_Title#> - <#menu5_19#></title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">

<link rel="shortcut icon" href="images/favicon.ico">
<link rel="icon" href="images/favicon.png">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/bootstrap.min.css">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/main.css">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/engage.itoggle.css">

<script type="text/javascript" src="/jquery.js"></script>
<script type="text/javascript" src="/bootstrap/js/bootstrap.min.js"></script>
<script type="text/javascript" src="/bootstrap/js/engage.itoggle.min.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/itoggle.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script type="text/javascript" src="/help.js"></script>

<script>
var $j = jQuery.noConflict();
<% routeflow_status(); %>
<% routeflow_gfw_state(); %>
<% routeflow_gfw_rows(); %>

$j(document).ready(function(){
	init_itoggle('routeflow_enable');
	init_itoggle('routeflow_dns_enable');
});

function initial(){
	show_banner(2);
	/* 本页使用自定义选项卡，L3 传 0 以免 show_menu 再渲染一条重复的选项卡栏
	 * （同时保留 #tabMenu 节点，show_menu 会向它写入空字符串） */
	show_menu(5,15,0);
	show_footer();
	fill_status(routeflow_status());
	$("routeflow_gfw_count").innerHTML = routeflow_gfw_count();
	$("routeflow_cidr_count").innerHTML = routeflow_cidr_count();
	$("rtf_kw").value = rtf_keyword;
	$("rtf_ckw").value = rtf_ckeyword;
	renderRows('gfw');
	renderRows('cidr');
	if(rtf_tab == 'cidr' || rtf_ckeyword != '')
		switchTab('cidr');
	else if(rtf_tab == 'gfw' || rtf_keyword != '')
		switchTab('gfw');
}

function switchTab(name){
	$j("#li_gen").removeClass("active");
	$j("#li_gfw").removeClass("active");
	$j("#li_cidr").removeClass("active");
	$j("#tab_gen").hide();
	$j("#tab_gfw").hide();
	$j("#tab_cidr").hide();
	$j("#li_" + name).addClass("active");
	$j("#tab_" + name).show();
}

function applyRule(){
	if(validForm()){
		showLoading();
		document.form.action_mode.value = " Restart ";
		document.form.current_page.value = "routeflow.asp";
		document.form.next_page.value = "";
		document.form.submit();
	}
}

function validForm(){
	var gw_obj = document.form.routeflow_gateway;
	if(!validate_ipaddr_final(gw_obj, ''))
		return false;
	return true;
}

function fill_status(status_code){
	var stext = "Unknown";
	if (status_code == 0)
		stext = "<#Stopped#>";
	else if (status_code == 1)
		stext = "<#Running#>";
	$("routeflow_status").innerHTML = '<span class="label label-' + (status_code != 0 ? 'success' : 'warning') + '">' + stext + '</span>';
}

function renderRows(kind){
	var isCidr = (kind == 'cidr');
	var rows = isCidr ? routeflow_cidr_rows() : routeflow_gfw_rows();
	var kw = isCidr ? rtf_ckeyword : rtf_keyword;
	var tb = $(isCidr ? "rtf_cidr_tbody" : "rtf_tbody");
	tb.innerHTML = "";
	if(rows.length == 0){
		var tr = document.createElement("tr");
		var td = document.createElement("td");
		td.colSpan = 3;
		td.style.textAlign = "center";
		td.style.color = "#999";
		if(kw == "")
			td.innerHTML = isCidr ? "<#menu5_19_36#>" : "<#menu5_19_18#>";
		else
			td.innerHTML = isCidr ? "<#menu5_19_35#>" : "<#menu5_19_23#>";
		tr.appendChild(td);
		tb.appendChild(tr);
		return;
	}
	for(var i = 0; i < rows.length; i++){
		var dom = rows[i][0];
		var tr = document.createElement("tr");

		var td1 = document.createElement("td");
		td1.innerHTML = (i + 1);
		tr.appendChild(td1);

		var td2 = document.createElement("td");
		var box = document.createElement("input");
		box.type = "text";
		box.className = "input";
		box.style.width = "100%";
		box.style.marginBottom = "0px";
		box.value = dom;
		td2.appendChild(box);
		tr.appendChild(td2);

		var td3 = document.createElement("td");
		td3.style.whiteSpace = "nowrap";
		var eb = document.createElement("input");
		eb.type = "button";
		eb.className = "btn btn-mini btn-primary";
		eb.value = "<#CTL_modify#>";
		eb.onclick = (function(k, orig, le){ return function(){ editDomain(k, orig, le); }; })(kind, dom, box);
		td3.appendChild(eb);
		td3.appendChild(document.createTextNode(" "));
		var db = document.createElement("input");
		db.type = "button";
		db.className = "btn btn-mini";
		db.value = "<#CTL_del#>";
		db.onclick = (function(k, orig){ return function(){ delDomain(k, orig); }; })(kind, dom);
		td3.appendChild(db);
		tr.appendChild(td3);

		tb.appendChild(tr);
	}
}

function doSearch(kind){
	var isCidr = (kind == 'cidr');
	var k = $(isCidr ? "rtf_ckw" : "rtf_kw").value.replace(/^\s+|\s+$/g, "");
	showLoading();
	if(isCidr)
		location.href = "/routeflow.asp?rtf_tab=cidr&ckeyword=" + encodeURIComponent(k);
	else
		location.href = "/routeflow.asp?rtf_tab=gfw&keyword=" + encodeURIComponent(k);
}

function doReset(kind){
	showLoading();
	location.href = "/routeflow.asp?rtf_tab=" + (kind == 'cidr' ? "cidr" : "gfw");
}

function submitAction(kind, action, oldd, newd){
	var isCidr = (kind == 'cidr');
	var f = isCidr ? document.cidrForm : document.gfwForm;
	f.routeflow_action.value = action;
	f.routeflow_old.value = oldd;
	f.routeflow_domain.value = newd;
	f.rtf_kw_back.value = isCidr ? rtf_ckeyword : rtf_keyword;
	showLoading();
	f.submit();
}

function addDomain(kind){
	var isCidr = (kind == 'cidr');
	var v = $(isCidr ? "rtf_cadd" : "rtf_add").value.replace(/^\s+|\s+$/g, "");
	if(v == ""){ alert(isCidr ? "<#menu5_19_29#>" : "<#menu5_19_22#>"); return; }
	if(!isCidr && v.indexOf('/') >= 0){ alert("<#menu5_19_38#>"); return; }
	if(!confirm(isCidr ? "<#menu5_19_30#>" : "<#menu5_19_20#>")) return;
	submitAction(kind, "add", "", v);
}

function editDomain(kind, orig, le){
	var isCidr = (kind == 'cidr');
	var nv = le.value.replace(/^\s+|\s+$/g, "");
	if(nv == ""){ alert(isCidr ? "<#menu5_19_29#>" : "<#menu5_19_22#>"); le.value = orig; return; }
	if(!isCidr && nv.indexOf('/') >= 0){ alert("<#menu5_19_38#>"); le.value = orig; return; }
	if(nv == orig) return;
	if(!confirm(isCidr ? "<#menu5_19_31#>" : "<#menu5_19_21#>")) return;
	submitAction(kind, "edit", orig, nv);
}

function delDomain(kind, orig){
	if(!confirm(kind == 'cidr' ? "<#menu5_19_32#>" : "<#menu5_19_19#>")) return;
	submitAction(kind, "delete", orig, "");
}

function enterKey(ev, fn){
	ev = ev || window.event;
	if(ev.keyCode == 13){ fn(); return false; }
	return true;
}
</script>

<style>
.nav-tabs > li > a {
    padding-right: 6px;
    padding-left: 6px;
}
.rtf_bar input[type="text"] {
	margin-bottom: 0px;
}
#rtf_list_box {
	max-height: 360px;
	overflow: auto;
}
</style>
</head>

<body onload="initial();" onunLoad="return unload_body();">

<div class="wrapper">
    <div class="container-fluid" style="padding-right: 0px">
        <div class="row-fluid">
            <div class="span3"><center><div id="logo"></div></center></div>
            <div class="span9" >
                <div id="TopBanner"></div>
            </div>
        </div>
    </div>

    <div id="Loading" class="popup_bg"></div>

    <iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>

    <div class="container-fluid">
        <div class="row-fluid">
            <div class="span3">
                <!--Sidebar content-->
                <!--=====Beginning of Main Menu=====-->
                <div class="well sidebar-nav side_nav" style="padding: 0px;">
                    <ul id="mainMenu" class="clearfix"></ul>
                    <ul class="clearfix">
                        <li>
                            <div id="subMenu" class="accordion"></div>
                        </li>
                    </ul>
                </div>
            </div>

            <div class="span9">
                <!--Body content-->
                <div class="row-fluid">
                    <div class="span12">
                        <div class="box well grad_colour_dark_blue">
                            <h2 class="box_head round_top"><#menu5_19#></h2>
                            <div class="round_bottom">
                                <div class="row-fluid">
                                    <div id="tabMenu" class="submenuBlock"></div>
                                    <ul id="tabs" class="nav nav-tabs">
                                        <li id="li_gen" class="active"><a href="javascript:void(0)" onclick="switchTab('gen');return false;"><#menu5_1_1#></a></li>
                                        <li id="li_gfw"><a href="javascript:void(0)" onclick="switchTab('gfw');return false;"><#menu5_19_5#></a></li>
                                        <li id="li_cidr"><a href="javascript:void(0)" onclick="switchTab('cidr');return false;"><#menu5_19_24#></a></li>
                                    </ul>

                                    <!-- ===== Tab: general settings ===== -->
                                    <form method="post" name="form" id="ruleForm" action="/start_apply.htm" target="hidden_frame">
                                    <input type="hidden" name="current_page" value="routeflow.asp">
                                    <input type="hidden" name="next_page" value="">
                                    <input type="hidden" name="next_host" value="">
                                    <input type="hidden" name="sid_list" value="routeflowConf;">
                                    <input type="hidden" name="group_id" value="">
                                    <input type="hidden" name="action_mode" value="">
                                    <input type="hidden" name="action_script" value="">

                                    <div id="tab_gen">
                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <tr> <th><#running_status#></th>
                                            <td id="routeflow_status" colspan="3"></td>
                                        </tr>

                                        <tr> <th><#menu5_19_1#></th>
                                            <td>
                                                <div class="main_itoggle">
                                                <div id="routeflow_enable_on_of">
                                                    <input type="checkbox" id="routeflow_enable_fake" <% nvram_match_x("", "routeflow_enable", "1", "value=1 checked"); %><% nvram_match_x("", "routeflow_enable", "0", "value=0"); %>>
                                                </div>
                                                </div>
                                                <div style="position: absolute; margin-left: -10000px;">
                                                    <input type="radio" value="1" name="routeflow_enable" id="routeflow_enable_1" <% nvram_match_x("", "routeflow_enable", "1", "checked"); %>><#checkbox_Yes#>
                                                    <input type="radio" value="0" name="routeflow_enable" id="routeflow_enable_0" <% nvram_match_x("", "routeflow_enable", "0", "checked"); %>><#checkbox_No#>
                                                </div>
                                            </td>
                                        </tr>

                                        <tr> <th width="50%"><#menu5_19_2#></th>
                                            <td>
                                                <input type="text" maxlength="15" class="input" size="15" name="routeflow_gateway" style="width: 145px" value="<% nvram_get_x("","routeflow_gateway"); %>" onkeypress="return is_ipaddr(this,event);"/>
                                            </td>
                                        </tr>

                                        <tr> <th><#menu5_19_4#></th>
                                            <td>
                                                <div class="main_itoggle">
                                                <div id="routeflow_dns_enable_on_of">
                                                    <input type="checkbox" id="routeflow_dns_enable_fake" <% nvram_match_x("", "routeflow_dns_enable", "1", "value=1 checked"); %><% nvram_match_x("", "routeflow_dns_enable", "0", "value=0"); %>>
                                                </div>
                                                </div>
                                                <div style="position: absolute; margin-left: -10000px;">
                                                    <input type="radio" value="1" name="routeflow_dns_enable" id="routeflow_dns_enable_1" <% nvram_match_x("", "routeflow_dns_enable", "1", "checked"); %>><#checkbox_Yes#>
                                                    <input type="radio" value="0" name="routeflow_dns_enable" id="routeflow_dns_enable_0" <% nvram_match_x("", "routeflow_dns_enable", "0", "checked"); %>><#checkbox_No#>
                                                </div>
                                            </td>
                                        </tr>

                                        <tr> <th width="50%"><#menu5_19_3#></th>
                                            <td>
                                                <input type="text" maxlength="48" class="input" size="24" name="routeflow_dns" style="width: 218px" value="<% nvram_get_x("","routeflow_dns"); %>">
                                            </td>
                                        </tr>

                                        <tr>
                                            <td colspan="2">
                                                <center><input class="btn btn-primary" style="width: 219px" type="button" value="<#CTL_apply#>" onclick="applyRule()" /></center>
                                            </td>
                                        </tr>
                                    </table>
                                    </div>
                                    </form>

                                    <!-- ===== Tab: GWF list ===== -->
                                    <div id="tab_gfw" style="display:none">
                                    <table width="100%" cellpadding="4" cellspacing="0" class="table rtf_bar">
                                        <tr> <th width="30%"><#menu5_19_6#></th>
                                            <td><span id="routeflow_gfw_count">0</span></td>
                                        </tr>
                                        <tr>
                                            <td colspan="2">
                                                <input type="text" id="rtf_add" class="input" size="24" style="width: 200px" placeholder="<#menu5_19_12#>" onkeypress="return enterKey(event, function(){ addDomain('gfw'); });">
                                                <input class="btn btn-primary" type="button" value="<#menu5_19_11#>" onclick="addDomain('gfw')">
                                                &nbsp;&nbsp;
                                                <input type="text" id="rtf_kw" class="input" size="24" style="width: 200px" placeholder="<#menu5_19_14#>" onkeypress="return enterKey(event, function(){ doSearch('gfw'); });">
                                                <input class="btn btn-primary" type="button" value="<#menu5_19_13#>" onclick="doSearch('gfw')">
                                                <input class="btn" type="button" value="<#menu5_19_15#>" onclick="doReset('gfw')">
                                            </td>
                                        </tr>
                                    </table>

                                    <form method="post" name="gfwForm" action="/routeflow_action.asp" target="hidden_frame">
                                    <input type="hidden" name="routeflow_action" value="">
                                    <input type="hidden" name="routeflow_old" value="">
                                    <input type="hidden" name="routeflow_domain" value="">
                                    <input type="hidden" name="rtf_kw_back" value="">
                                    <input type="hidden" name="rtf_list" value="gfw">
                                    <input type="hidden" name="current_page" value="routeflow.asp">

                                    <div id="rtf_list_box">
                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <thead>
                                            <tr>
                                                <th style="width: 50px;">#</th>
                                                <th><#menu5_19_16#></th>
                                                <th style="width: 130px;"><#menu5_19_17#></th>
                                            </tr>
                                        </thead>
                                        <tbody id="rtf_tbody"></tbody>
                                    </table>
                                    </div>
                                    </form>

                                    <form method="post" name="uploadForm" action="/routeflow_upload.cgi" enctype="multipart/form-data" target="hidden_frame" onsubmit="showLoading();">
                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <tr>
                                            <td>
                                                <#menu5_19_10#><br>
                                                <input type="file" name="routeflow_file" style="width: 300px" required>
                                                <input class="btn btn-primary" style="width: 140px" type="submit" value="<#menu5_19_9#>" />
                                            </td>
                                        </tr>
                                    </table>
                                    </form>
                                    </div>

                                    <!-- ===== Tab: CIDR list ===== -->
                                    <div id="tab_cidr" style="display:none">
                                    <table width="100%" cellpadding="4" cellspacing="0" class="table rtf_bar">
                                        <tr> <th width="30%"><#menu5_19_25#></th>
                                            <td><span id="routeflow_cidr_count">0</span></td>
                                        </tr>
                                        <tr>
                                            <td colspan="2">
                                                <input type="text" id="rtf_cadd" class="input" size="24" style="width: 200px" placeholder="<#menu5_19_27#>" onkeypress="return enterKey(event, function(){ addDomain('cidr'); });">
                                                <input class="btn btn-primary" type="button" value="<#menu5_19_26#>" onclick="addDomain('cidr')">
                                                &nbsp;&nbsp;
                                                <input type="text" id="rtf_ckw" class="input" size="24" style="width: 200px" placeholder="<#menu5_19_14#>" onkeypress="return enterKey(event, function(){ doSearch('cidr'); });">
                                                <input class="btn btn-primary" type="button" value="<#menu5_19_13#>" onclick="doSearch('cidr')">
                                                <input class="btn" type="button" value="<#menu5_19_15#>" onclick="doReset('cidr')">
                                            </td>
                                        </tr>
                                    </table>

                                    <form method="post" name="cidrForm" action="/routeflow_action.asp" target="hidden_frame">
                                    <input type="hidden" name="routeflow_action" value="">
                                    <input type="hidden" name="routeflow_old" value="">
                                    <input type="hidden" name="routeflow_domain" value="">
                                    <input type="hidden" name="rtf_kw_back" value="">
                                    <input type="hidden" name="rtf_list" value="cidr">
                                    <input type="hidden" name="current_page" value="routeflow.asp">

                                    <div id="rtf_cidr_list_box">
                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <thead>
                                            <tr>
                                                <th style="width: 50px;">#</th>
                                                <th><#menu5_19_28#></th>
                                                <th style="width: 130px;"><#menu5_19_17#></th>
                                            </tr>
                                        </thead>
                                        <tbody id="rtf_cidr_tbody"></tbody>
                                    </table>
                                    </div>
                                    </form>

                                    <form method="post" name="cidrUploadForm" action="/routeflow_cidr_upload.cgi" enctype="multipart/form-data" target="hidden_frame" onsubmit="showLoading();">
                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <tr>
                                            <td>
                                                <#menu5_19_33#><br>
                                                <span style="color:#999"><#menu5_19_34#></span><br>
                                                <input type="file" name="routeflow_cidr_file" style="width: 300px" required>
                                                <input class="btn btn-primary" style="width: 140px" type="submit" value="<#menu5_19_37#>" />
                                            </td>
                                        </tr>
                                    </table>
                                    </form>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div id="footer"></div>
</div>

</body>
</html>
