<#import "template.ftl" as layout>
<@layout.registrationLayout; section>
    <#if section = "header">
        <script>
            document.title =  "${msg("frontchannel-logout.title")}";
        </script>
        <span class="nm-head">
            <span class="nm-head__title">${msg("frontchannel-logout.title")}</span>
        </span>
    <#elseif section = "form">
        <p>${msg("frontchannel-logout.message")}</p>
        <ul>
        <#list logout.clients as client>
            <li>
                ${client.name}
                <iframe src="${client.frontChannelLogoutUrl}" style="display:none;"></iframe>
            </li>
        </#list>
        </ul>
        <#if logout.logoutRedirectUri?has_content>
            <script>
                function readystatechange(event) {
                    if (document.readyState=='complete') {
                        window.location.replace('${logout.logoutRedirectUri}');
                    }
                }
                document.addEventListener('readystatechange', readystatechange);
            </script>
            <div class="nm-btn-stack">
                <a id="continue" class="nm-btn nm-btn-primary" href="${logout.logoutRedirectUri}">${msg("doContinue")}</a>
            </div>
        </#if>
    </#if>
</@layout.registrationLayout>
