# Third-Party Software & Tooling Notices

This project uses and packages software licensed under various open-source licenses. Below are the attributions, notices, and licenses of the third-party tools and components utilized in this distribution pipeline.

---

### 1. OpenSSL
* **Website:** [https://www.openssl.org/](https://www.openssl.org/)
* **License:** [Apache License 2.0](https://github.com/openssl/openssl/blob/master/LICENSE.txt)
* **Usage:** Core cryptographic libraries (`libcrypto`, `libssl`), CLI utility (`openssl`), headers, and documentation redistributed in this repository.

---

### 2. Inno Setup
* **Author:** Jordan Russell / Martijn Laan
* **Website:** [https://jrsoftware.org/isinfo.php](https://jrsoftware.org/isinfo.php)
* **License:** [Inno Setup License (Modified BSD/zlib style)](https://jrsoftware.org/files/is/license.txt)
* **Usage:** Used to compile the Windows Multi-Architecture Setup installer (`.exe`).

---

### 3. WiX Toolset
* **Organization:** .NET Foundation / Outercurve Foundation
* **Website:** [https://wixtoolset.org/](https://wixtoolset.org/)
* **License:** [Microsoft Reciprocal License (MS-RL)](https://github.com/wixtoolset/wix/blob/main/LICENSE.TXT)
* **Usage:** Used to compile the enterprise Windows Installer packages (`.msi`).

---

### 4. Microsoft Windows SDK & Azure Trusted Signing Action
* **Publisher:** Microsoft Corporation
* **Tools:** `MakeAppx.exe`, `SignTool.exe`, `azure/artifact-signing-action`
* **License:** [Microsoft Software License Terms](https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/) / [MIT License](https://github.com/Azure/artifact-signing-action/blob/main/LICENSE)
* **Usage:** Used for MSIX packaging, Authenticode signing, and signature verification.