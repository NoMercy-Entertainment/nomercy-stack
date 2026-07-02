<#import "template.ftl" as layout>
<#import "password-commons.ftl" as passwordCommons>
<@layout.registrationLayout; section>

<#if section = "header">
    <span class="nm-head">
        <span class="nm-head__title">${msg("recovery-code-config-header")}</span>
    </span>
<#elseif section = "form">
    <div class="nm-prose">
        <div class="nm-alert nm-alert--warning" aria-label="Warning alert">
            <h4>
                <span class="pf-screen-reader">Warning alert:</span>
                ${msg("recovery-code-config-warning-title")}
            </h4>
            <p>${msg("recovery-code-config-warning-message")}</p>
        </div>

        <ol id="kc-recovery-codes-list" class="kc-recovery-codes-list nm-codes">
            <#list recoveryAuthnCodesConfigBean.generatedRecoveryAuthnCodesList as code>
                <li><span>${code?counter}:</span> ${code[0..3]}-${code[4..7]}-${code[8..]}</li>
            </#list>
        </ol>

        <div class="nm-row">
            <button id="printRecoveryCodes" class="nm-btn nm-btn-ghost" type="button">
                <i class="pficon-print"></i> ${msg("recovery-codes-print")}
            </button>
            <button id="downloadRecoveryCodes" class="nm-btn nm-btn-ghost" type="button">
                <i class="pficon-save"></i> ${msg("recovery-codes-download")}
            </button>
            <button id="copyRecoveryCodes" class="nm-btn nm-btn-ghost" type="button">
                <i class="pficon-blueprint"></i> ${msg("recovery-codes-copy")}
            </button>
        </div>

        <label class="nm-check">
            <input type="checkbox" id="kcRecoveryCodesConfirmationCheck" name="kcRecoveryCodesConfirmationCheck"
                   onchange="document.getElementById('saveRecoveryAuthnCodesBtn').disabled = !this.checked;"/>
            <span>${msg("recovery-codes-confirmation-message")}</span>
        </label>

        <form action="${url.loginAction}" class="nm-form" id="kc-recovery-codes-settings-form" method="post">
            <input type="hidden" name="generatedRecoveryAuthnCodes" value="${recoveryAuthnCodesConfigBean.generatedRecoveryAuthnCodesAsString}" />
            <input type="hidden" name="generatedAt" value="${recoveryAuthnCodesConfigBean.generatedAt?c}" />
            <input type="hidden" id="userLabel" name="userLabel" value="${msg("recovery-codes-label-default")}" />
            <@passwordCommons.logoutOtherSessions/>

            <#if isAppInitiatedAction??>
                <div class="nm-btn-stack">
                    <button type="submit" class="nm-btn nm-btn-primary" id="saveRecoveryAuthnCodesBtn" disabled>${msg("recovery-codes-action-complete")}</button>
                    <button type="submit" class="nm-btn nm-btn-ghost" id="cancelRecoveryAuthnCodesBtn" name="cancel-aia" value="true">${msg("recovery-codes-action-cancel")}</button>
                </div>
            <#else>
                <div class="nm-btn-stack">
                    <button type="submit" class="nm-btn nm-btn-primary" id="saveRecoveryAuthnCodesBtn" disabled>${msg("recovery-codes-action-complete")}</button>
                </div>
            </#if>
        </form>
    </div>

    <script>
        /* copy recovery codes  */
        function copyRecoveryCodes() {
            var tmpTextarea = document.createElement("textarea");
            var codes = document.getElementById("kc-recovery-codes-list").getElementsByTagName("li");
            for (i = 0; i < codes.length; i++) {
                tmpTextarea.value = tmpTextarea.value + codes[i].innerText + "\n";
            }
            document.body.appendChild(tmpTextarea);
            tmpTextarea.select();
            document.execCommand("copy");
            document.body.removeChild(tmpTextarea);
        }

        var copyButton = document.getElementById("copyRecoveryCodes");
        copyButton && copyButton.addEventListener("click", function () {
            copyRecoveryCodes();
        });

        /* download recovery codes  */
        function formatCurrentDateTime() {
            var dt = new Date();
            var options = {
                month: 'long',
                day: 'numeric',
                year: 'numeric',
                hour: 'numeric',
                minute: 'numeric',
                timeZoneName: 'short'
            };

            return dt.toLocaleString('en-US', options);
        }

        function parseRecoveryCodeList() {
            var recoveryCodes = document.querySelectorAll(".kc-recovery-codes-list li");
            var recoveryCodeList = "";

            for (var i = 0; i < recoveryCodes.length; i++) {
                var recoveryCodeLiElement = recoveryCodes[i].innerText;
                recoveryCodeList += recoveryCodeLiElement + "\r\n";
            }

            return recoveryCodeList;
        }

        function buildDownloadContent() {
            var recoveryCodeList = parseRecoveryCodeList();
            var dt = new Date();
            var options = {
                month: 'long',
                day: 'numeric',
                year: 'numeric',
                hour: 'numeric',
                minute: 'numeric',
                timeZoneName: 'short'
            };

            return fileBodyContent =
                "${msg("recovery-codes-download-file-header")}\n\n" +
                recoveryCodeList + "\n" +
                "${msg("recovery-codes-download-file-description")}\n\n" +
                "${msg("recovery-codes-download-file-date")} " + formatCurrentDateTime();
        }

        function setUpDownloadLinkAndDownload(filename, text) {
            var el = document.createElement('a');
            el.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(text));
            el.setAttribute('download', filename);
            el.style.display = 'none';
            document.body.appendChild(el);
            el.click();
            document.body.removeChild(el);
        }

        function downloadRecoveryCodes() {
            setUpDownloadLinkAndDownload('kc-download-recovery-codes.txt', buildDownloadContent());
        }

        var downloadButton = document.getElementById("downloadRecoveryCodes");
        downloadButton && downloadButton.addEventListener("click", downloadRecoveryCodes);

        /* print recovery codes */
        function buildPrintContent() {
            var recoveryCodeListHTML = document.getElementById('kc-recovery-codes-list').innerHTML;
            var styles =
                `@page { size: auto;  margin-top: 0; }
                body { width: 480px; }
                div { list-style-type: none; font-family: monospace }
                p:first-of-type { margin-top: 48px }`

            return printFileContent =
                "<html><style>" + styles + "</style><body>" +
                "<title>kc-download-recovery-codes</title>" +
                "<p>${msg("recovery-codes-download-file-header")}</p>" +
                "<div>" + recoveryCodeListHTML + "</div>" +
                "<p>${msg("recovery-codes-download-file-description")}</p>" +
                "<p>${msg("recovery-codes-download-file-date")} " + formatCurrentDateTime() + "</p>" +
                "</body></html>";
        }

        function printRecoveryCodes() {
            var w = window.open();
            w.document.write(buildPrintContent());
            w.print();
            w.close();
        }

        var printButton = document.getElementById("printRecoveryCodes");
        printButton && printButton.addEventListener("click", printRecoveryCodes);
    </script>
</#if>
</@layout.registrationLayout>
