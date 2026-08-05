<#import "template.ftl" as layout>
<@layout.registrationLayout; section>
    <#if section = "header">
        <h1 class="nm-head__title">
            <#if code.success>
                ${msg("codeSuccessTitle")}
            <#else>
                ${kcSanitize(msg("codeErrorTitle", code.error))}
            </#if>
        </h1>
    <#elseif section = "form">
        <div id="kc-code">
            <#if code.success>
                <p>${msg("copyCodeInstruction")}</p>
                <input id="code" class="${properties.kcTextareaClass!}" value="${code.code}"/>
            <#else>
                <p id="error">${kcSanitize(code.error)}</p>
            </#if>
        </div>
    </#if>
</@layout.registrationLayout>
