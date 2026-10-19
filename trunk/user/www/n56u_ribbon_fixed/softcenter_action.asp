<!DOCTYPE html>
<html>
<head>
<title></title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">

<link rel="shortcut icon" href="images/favicon.ico">
<link rel="icon" href="images/favicon.png">
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script>

function Callback(){
	setTimeout("document.redirectForm.submit();", 0);
}
</script>
</head>

<body onLoad="Callback();">
<% softcenter_action(); %>

<form method="post" name="redirectForm" action="/softcenter.asp" target="_self">
</form>

</body>
</html>
