# net-tester
Advanced Network Protocol &amp; Quality Tester for Tunneling
# Network Tester by A-battousai

این اسکریپت برای تست پورت‌ها، پروتکل‌ها و کیفیت شبکه بین دو سرور طراحی شده است.
<img width="1280" height="493" alt="image" src="https://github.com/user-attachments/assets/ad779cc7-a899-4001-a870-d53ecc4b831b" />

## نحوه استفاده:
برای اجرا روی هر دو سرور ایران و خارج، دستور زیر را وارد کنید
(تست یک طرفه هم میشه، مثلا فقط روی خارج دستور زیر رو بزنید و ip ایران و بزنید، ولی مطمعن بشید که پورت های مورد نیاز مثل 9000, 5201 داخل ufw باز باشه..):

```bash
bash <(curl -Ls https://raw.githubusercontent.com/A-battousai/net-tester/main/net-tester.sh)





## Contributors
Special thanks to [@RivenBytes](https://github.com/RivenBytes) for improving IP sanitization and UI clarity.
