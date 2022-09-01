#!/usr/bin/env python3

from netmiko import ConnectHandler
from netmiko import Netmiko
from netmiko.exceptions import NetmikoTimeoutException 


# def main():
#     ip_list = [
#         "10.0.0.1", "10.0.0.2", "10.0.0.3",
#         "10.0.0.4", "10.0.0.254"
#     ]

#     for ip in ip_list:
#         try:
#             hostname = ip
#             # username = "devnet_automation"
#             # password = "D3vN3t_automation"
#             username = "cisco"
#             password = "cisco"
#             ssh_connection = Netmiko(
#                 device_type="cisco_ios", host=hostname,
#                 username=username, password=password, secret=password)

#             ssh_connection.enable()

#             # Documenten
#             output = ssh_connection.send_command("show cdp")
#             if output.splitlines() != 1:
#                 output = output.splitlines()
#             else:
#                 pass

#             if "Sending CDPv2 advertisements is  enabled" in output[-1]:
#                 ssh_connection.send_config_set("no cdp run")
#                 print(f"Deshabilitaste CDP en el dispositivo {ip}")
#             else:
#                 print(f"Ya se encuentra deshabilita cdp en {ip}")

#             # if "% LLDP is not enabled" in output:
#             #     ssh_connection.send_config_set("lldp run")
#             #     print(f"Ya habilite LLDP en {ip}")
#             # else:
#             #     print(f"LLDP esta habilitado en {ip}")

#             # with open(file=f"{hostname}-startup-config.txt", mode="w") as f:
#             #     f.write(output)

#             ssh_connection.disconnect()

#         except NetmikoTimeoutException:
#             print(f"No se encuentra el dispositivo {ip}")


# if __name__ == "__main__":
#     main()





def main():
    ip_list = [
        "10.0.0.1", "10.0.0.2", "10.0.0.3",
        "10.0.0.4", "10.0.0.254", "10.0.0.11" ##  agrege el 11 para probar el script cuando no jalaba uno 
    ]


	### for para leer los elementos de la lista declarados aqui arribita abajito del mein 
    for ip in ip_list:
        try:
		    # username = "devnet_automation"
            # password = "D3vN3t_automation"
			### declaracion de variables 
			
			###  yo cree esos usuarios por que eran mas faciles para mi y me pale perca
            hostname = ip  ###   esta variable va ser la ip de la lista declarada arribita debajito del main 
            username = "cisco"
            password = "cisco"
			
			### Use a dictionary to pass the login parameters - en este caso el diccionario se llama ssh_connection
            ssh_connection = Netmiko(
                device_type="cisco_ios",
                host=hostname,
                username=username,
				password=password,
				secret=password)


			### probar que pedo es ssh_connection  
            ### vamos a ver que va ser de tipo class CiscoIosSSH 
            print("amos viendo que hay en ssh connection", ssh_connection)
            print("amos viendo el typo de esta vaina de ssh connection")
            print(type(ssh_connection))

			###coneccion aca mamalona con el divais  el punto enable nos conecta con el divais  
            ssh_connection.enable()

            # Documenten
			### variable output se usa para guardar la info del chow sedepe 
			## se manda el comando con el send_command
            output = ssh_connection.send_command("show cdp")
            print("esto trai el output antes del split a ver que once", output)
			### aqui vamos a dividir el pinchi output y si es diferente a 1 va dividir las linias si no pos va pasar eda al pinchi else
            if output.splitlines() != 1:
                output = output.splitlines()
                print("esto trai el output despues del split a ver que once", output)
                    
            else:
               pass


			### aqui va pasar a la otra comparacione eda  si el pinchi output trae ese mensaje de que el cdp esta habilitado entonces 
			### le vamos a mandar el no cdp y mandar el mensaje "Deshabilitaste CDP papus
			
            if "Sending CDPv2 advertisements is  enabled" in output[-1]:
			
			
                ssh_connection.send_config_set("no cdp run")
                print(f"Deshabilitaste CDP en el dispositivo {ip}")
				
			### si ya esta desabilitado nomas va mandar ese mensaje con la ip eda	
            else:
                print(f"Ya se encuentra deshabilita cdp en {ip}")

            # if "% LLDP is not enabled" in output:
            #     ssh_connection.send_config_set("lldp run")
            #     print(f"Ya habilite LLDP en {ip}")
            # else:
            #     print(f"LLDP esta habilitado en {ip}")

            # with open(file=f"{hostname}-startup-config.txt", mode="w") as f:
            #     f.write(output)


			###  recuerda siempre desconectarte del equipo apa por que 
            ssh_connection.disconnect()
		
		###  el excenpt pa cuando no jala un equipo 
        except NetmikoTimeoutException:
            print(f"No se encuentra el dispositivo {ip}")



###### correr el mein 
if __name__ == "__main__":
    main()







