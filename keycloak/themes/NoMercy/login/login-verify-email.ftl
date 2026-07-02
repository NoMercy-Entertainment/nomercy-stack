<#import "template.ftl" as layout>
<@layout.registrationLayout displayInfo=true; section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("emailVerifyTitle")}</span>
        </span>
    <#elseif section = "form">
        <p>${msg("emailVerifyInstruction1",user.email)}</p>
    <#elseif section = "info">
        <p>
            ${msg("emailVerifyInstruction2")}
            <br/>
            <a href="${url.loginAction}">${msg("doClickHere")}</a> ${msg("emailVerifyInstruction3")}
        </p>
    </#if>
</@layout.registrationLayout>
