function acao(param)
{
    var xmlhttp = new XMLHttpRequest();
    xmlhttp.open("GET", ("http://localhost:8080/VagasEstacionamento/ServerVagas?vaga=" + param), false);
    xmlhttp.send();
    document.getElementById("vagaX").style.backgroundColor = xmlhttp.responseText.trim().startsWith("{") ? JSON.parse(xmlhttp.responseText.trim()) : xmlhttp.responseText.trim();
//    return xmlhttp.responseText.trim().startsWith("{") ? JSON.parse(xmlhttp.responseText.trim()) : xmlhttp.responseText.trim();
//    return true;
}