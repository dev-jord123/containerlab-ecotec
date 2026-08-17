#!/usr/bin/env bash
# Menú interactivo para Pruebas de Funcionamiento - ContainerLab ECOTEC

PROYECTO="/opt/containerlab-ecotec"
RESPALDOS="/opt/respaldos"

# Asegurar que el script se ejecuta desde la carpeta del proyecto
cd "$PROYECTO" || { echo "Error: No se encontró el directorio $PROYECTO"; exit 1; }

mostrar_menu() {
    clear
    echo "=========================================================="
    echo "      MENÚ DE PRUEBAS - CONTAINERLAB ECOTEC"
    echo "=========================================================="
    echo "1) Prueba de balanceo de carga"
    echo "2) Prueba de tolerancia a fallos (Caída de app-1)"
    echo "3) Prueba de persistencia (Recrear Base de Datos)"
    echo "4) Prueba de reinicio del servidor (ATENCIÓN: Reinicia el SO)"
    echo "5) Restaurar datos desde un respaldo (.tar.gz)"
    echo "6) Salir"
    echo "=========================================================="
    read -p "Seleccione una opción [1-6]: " opcion
    echo ""
}

while true; do
    mostrar_menu
    case $opcion in
        1)
            echo "--- Ejecutando Prueba de Balanceo ---"
            for i in {1..10}; do 
                curl -s http://localhost:8080/ | grep -o 'app-[12]' | head -1
            done
            echo ""
            read -p "Presione Enter para regresar al menú..."
            ;;
        2)
            echo "--- Ejecutando Prueba de Tolerancia a Fallos ---"
            echo "Deteniendo app-1..."
            docker compose stop app-1
            docker compose ps -a
            echo ""
            echo "Comprobando disponibilidad (el portal debe seguir respondiendo por app-2)..."
            for i in {1..6}; do 
                curl -s http://localhost:8080/ | grep -o 'app-[12]' | head -1
            done
            curl -s -o /dev/null -w 'Código de respuesta general: HTTP %{http_code}\n' http://localhost:8080/
            echo ""
            echo "Restaurando app-1..."
            docker compose start app-1
            echo "Espere unos segundos a que la instancia vuelva al estado healthy..."
            read -p "Presione Enter para regresar al menú..."
            ;;
        3)
            echo "--- Ejecutando Prueba de Persistencia ---"
            echo "Deteniendo y eliminando contenedor de base de datos..."
            docker compose stop base-datos
            docker compose rm -f base-datos
            echo ""
            echo "Verificando que el volumen sigue existiendo (debe aparecer containerlab-ecotec_datos_bd):"
            docker volume ls | grep datos_bd
            echo ""
            echo "Recreando el contenedor..."
            docker compose up -d base-datos
            echo "Verifique en el portal que el contador de visitas no se reinició."
            read -p "Presione Enter para regresar al menú..."
            ;;
        4)
            echo "--- Prueba de Reinicio del Servidor ---"
            echo "ATENCIÓN: Esto ejecutará 'sudo reboot' y cerrará tu sesión actual."
            read -p "¿Está seguro de querer reiniciar el servidor AHORA? (s/n): " confirmar
            if [[ "$confirmar" == "s" || "$confirmar" == "S" ]]; then
                echo "Reiniciando el servidor..."
                sudo reboot
            else
                echo "Reinicio cancelado."
                read -p "Presione Enter para regresar al menú..."
            fi
            ;;
        5)
            echo "--- Restaurar desde un respaldo ---"
            echo "Respaldos disponibles en $RESPALDOS:"
            ls -lh "$RESPALDOS"
            echo ""
            read -p "Ingrese el nombre EXACTO del archivo (ej. respaldo_containerlab_20260816_120000.tar.gz): " archivo_respaldo
            
            if [ -f "$RESPALDOS/$archivo_respaldo" ]; then
                # Extraer la fecha del nombre del archivo para saber a qué carpeta entrar
                fecha_respaldo=$(echo "$archivo_respaldo" | sed 's/respaldo_containerlab_//;s/\.tar\.gz//')
                carpeta_extraccion="respaldo_$fecha_respaldo"
                
                cd /tmp
                echo "Extrayendo archivo en /tmp..."
                tar -xzf "$RESPALDOS/$archivo_respaldo"
                
                if [ -d "$carpeta_extraccion" ]; then
                    cd "$carpeta_extraccion"
                    echo "Cargando el volcado a la base de datos..."
                    source "$PROYECTO/.env"
                    docker exec -i base-datos mariadb -u root -p"$DB_ROOT_PASSWORD" < smartservices.sql
                    
                    echo "Verificando la restauración (Tabla de servicios):"
                    docker exec -it base-datos mariadb -u smartuser -p smartservices -e "SELECT id, nombre FROM servicios;"
                else
                    echo "Error: No se encontró la carpeta $carpeta_extraccion tras extraer el archivo."
                fi
                # Regresar al proyecto
                cd "$PROYECTO"
            else
                echo "Error: No se encontró el archivo $RESPALDOS/$archivo_respaldo"
            fi
            read -p "Presione Enter para regresar al menú..."
            ;;
        6)
            echo "Saliendo del menú..."
            exit 0
            ;;
        *)
            echo "Opción inválida. Por favor, seleccione un número del 1 al 6."
            read -p "Presione Enter para continuar..."
            ;;
    esac
done
