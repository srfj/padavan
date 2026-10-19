<!DOCTYPE html>
<html>
<head>
<title><#Web_Title#> - <#menu5_20#></title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">

<link rel="shortcut icon" href="images/favicon.ico">
<link rel="icon" href="images/favicon.png">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/bootstrap.min.css">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/main.css">

<script type="text/javascript" src="/jquery.js"></script>
<script type="text/javascript" src="/bootstrap/js/bootstrap.min.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script type="text/javascript" src="/help.js"></script>

<script>
var $j = jQuery.noConflict();
<% softcenter_status(); %>
<% softcenter_plugins(); %>

function escapeHTML(s){
	return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function initial(){
	show_banner(2);
	show_menu(5,16,1);
	show_footer();
	$("softcenter_count").innerHTML = softcenter_count();
	buildPluginList();
}

function buildPluginList(){
	var plugins = softcenter_plugins();
	var html = "";
	if (plugins.length == 0){
		html = '<tr><td colspan="4" style="text-align: center"><#menu5_20_9#></td></tr>';
	} else {
		for (var i = 0; i < plugins.length; i++){
			html += '<tr>'
				+ '<td>' + escapeHTML(plugins[i][0]) + '</td>'
				+ '<td>' + escapeHTML(plugins[i][1]) + '</td>'
				+ '<td>' + escapeHTML(plugins[i][2]) + '</td>'
				+ '<td style="text-align: center"><input class="btn btn-danger btn-mini" type="button" value="<#menu5_20_5#>" onclick="scRemove(\'' + escapeHTML(plugins[i][0]) + '\')"></td>'
				+ '</tr>';
		}
	}
	$("plugin_list").innerHTML = html;
}

function scRemove(name){
	if (!confirm("<#menu5_20_10#>"))
		return;
	showLoading();
	document.scForm.softcenter_action.value = "remove";
	document.scForm.softcenter_name.value = name;
	document.scForm.submit();
}

function applyUpload(){
	var file_obj = document.uploadForm.softcenter_file;
	if (file_obj.value == ""){
		alert("<#menu5_20_11#>");
		return false;
	}
	if (!/\.pak$/i.test(file_obj.value)){
		alert("<#menu5_20_12#>");
		return false;
	}
	showLoading();
	return true;
}
</script>
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
                            <h2 class="box_head round_top"><#menu5_20#></h2>
                            <div class="round_bottom">
                                <div class="row-fluid">
                                    <div id="tabMenu" class="submenuBlock"></div>
                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <tr>
                                            <th width="50%"><#menu5_20_2#></th>
                                            <td><span id="softcenter_count">0</span></td>
                                        </tr>
                                    </table>
                                </div>
                            </div>
                        </div>

                        <div class="box well grad_colour_dark_blue">
                            <h2 class="box_head round_top"><#menu5_20_1#></h2>
                            <div class="round_bottom">
                                <div class="row-fluid">
                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <tr>
                                            <th><#menu5_20_3#></th>
                                            <th><#menu5_20_4#></th>
                                            <th><#menu5_20_7#></th>
                                            <th></th>
                                        </tr>
                                        <tbody id="plugin_list"></tbody>
                                    </table>
                                </div>
                            </div>
                        </div>

                        <div class="box well grad_colour_dark_blue">
                            <h2 class="box_head round_top"><#menu5_20_6#></h2>
                            <div class="round_bottom">
                                <div class="row-fluid">
                                    <form method="post" name="uploadForm" action="/softcenter_upload.cgi" enctype="multipart/form-data" target="hidden_frame" onsubmit="return applyUpload();">
                                    <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                        <tr>
                                            <td>
                                                <#menu5_20_8#><br>
                                                <input type="file" name="softcenter_file" accept=".pak" style="width: 300px" required>
                                                <input class="btn btn-primary" style="width: 140px" type="submit" value="<#menu5_20_6#>" />
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

    <form method="post" name="scForm" action="/softcenter_action.asp" target="hidden_frame">
    <input type="hidden" name="softcenter_action" value="">
    <input type="hidden" name="softcenter_name" value="">
    </form>

    <div id="footer"></div>
</div>

</body>
</html>
