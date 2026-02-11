# net-tester
Advanced Network Protocol &amp; Quality Tester for Tunneling
# Network Tester by A-battousai

این اسکریپت برای تست پورت‌ها، پروتکل‌ها و کیفیت شبکه بین دو سرور طراحی شده است.

## نحوه استفاده:
برای اجرا روی هر دو سرور ایران و خارج، دستور زیر را وارد کنید
(تست یک طرفه هم میشه، مثلا فقط روی خارج دستور زیر رو بزنید و ip ایران و بزنید، ولی مطمعن بشید که پورت های مورد نیاز مثل 9000, 5201 داخل ufw باز باشه..):

```bash
bash <(curl -Ls https://raw.githubusercontent.com/A-battousai/net-tester/main/net-tester.sh)
