#!/bin/bash

################################ DESCRIÇÃO #################################
#--------------------------------------------------------------------------#
# Autor: Lucas Santos © MIT                               Data: 13/03/2017 #
#--------------------------------------------------------------------------#
#                                                                          #
# Cria uma interface entre o usuário e a AWS para criar imagens AMI        #
# de forma remota, assim é só necessário executar o programa com as infos  #
# corretas (id da instancia  e região) para que seja criada uma nova AMI   #
# no painel do console da AWS.                                             #
#                                                                          #
#--------------------------------------------------------------------------#
#                                                                          #
# Parâmetros:                                                              #
#     -r [us-east-1, us-east-2]: Região de uso                             #
#     -i [ID da instancia]: ID (do tipo i-...) da instancia AWS            #
#     -h: Mostra texto de ajuda                                            #
#     -T: Inicia modo de testes, nada é executado apenas testa a chamada   #
#                                                                          #
############################################################################

## VARIÁVEIS E ESTÁTICOS ##

#Cores
RED='\033[0;031m'
CYAN='\033[0;036m'
YELLOW='\033[1;33m'
BLACK='\033[0;30m'
DARKGRAY='\033[1;30m'
LIGHTRED='\033[1;31m'
GREEN='\033[0;32m'
LIGHTGREEN='\033[1;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
LIGHTBLUE='\033[1;34m'
PURPLE='\033[0;35m'
LIGHTPURPLE='\033[1;35m'
LIGHTCYAN='\033[1;36m'
LIGHTGRAY='\033[0;37m'
WHITE='\033[1;37m'
NC='\033[0m'

#Define a instancia
instance=""
#Define a região (padrão dev)
region=""
#Define o modo de testes
dry_run=""
#Nome da instancia
instance_name=""

# Busca o nome da instancia na AWS ($instancia, $regiao)
# @param $instance id da instancia
# @param $region Nome da região
getInstanceName () {
  instance_name="$(aws ec2 describe-instances --region $2 --query "Reservations[*].Instances[*].[Tags[?Key=='Name'].Value]" --instance-id $1 --output text)"
}





## FLAGS ##
# Parsing das opções
while getopts ":i:r:Th" param; do
  case $param in
    i)
      instance=${OPTARG-""}
      ;;
    r)
      region=${OPTARG-"us-east-1"}
      ;;
    T)
      dry_run="--dry-run"
      ;;
    h)
      echo -e "${ORANGE}# Script de criação de imagem AMI remota${NC}"
      echo -e "-> Opções:"
      echo -e "     ${PURPLE}-i${NC}    Define o ID de uma instancia (${YELLOW}Geralmente começa com${NC} ${CYAN}i-<numeros>${NC})"
      echo -e "     ${PURPLE}-r${NC}    Define a região a ser usada (${YELLOW}us-east-1 ou us-east-2${NC})"
      echo -e "     ${PURPLE}-T${NC}    Liga o modo de testes (nenhuma ação é realizada, apenas testa a chamada)"
      exit
      ;;
    \?)
      echo -e "Opção Inválida: ${RED}-$OPTARG${NC}" >&2
      exit
      ;;
    :)
      echo -e "Opção ${YELLOW}-$OPTARG${NC} precisa de um argumento." >&2
      exit
      ;;
  esac
done





## PROCESSOS DE INSTALAÇÃO ##
# Procedimentos de checagem para ver se já está instalado ou não
echo -e "${CYAN}Checando instalação do aws cli${NC}"
if ! which aws &> /dev/null; then
  echo -e "${RED}AWS CLI não está instalado, deseja instalar? [Y,n]${NC}"
  read install
  install=${install:-"Y"}

  if [[ $install == "Y" ]] || [[ $install == "y" ]] ; then
    echo -e "${CYAN}Instalando...${NC}"

    OS="`uname`"
    case $OS in
      'Linux')
        echo -e "Sua distribuição do Linux é baseada em:"
        echo -e "1) Debian (Ubuntu e derivados)"
        echo -e "2) Fedora, Red Hat, RHEL"
        echo -e "3) OpenSUSE, SUSE"
        read distro
        echo -e "${CYAN}Instalando python${NC}"
        case $distro in
          "1")
            sudo apt-get install python 3.4
            ;;
          "2")
           sudo yum install python 34
            ;;
          "3")
            sudo zypper install python3-3.4.1
            ;;
        esac
        echo -e "${CYAN}Obtendo pip${NC}"
        curl -O https://bootstrap.pypa.io/get-pip.py
        python3 get-pip.py --user
        echo -e "${GREEN}Criando variável de ambiente${NC}"
        export PATH=~/.local/bin:$PATH >> ~/.bash_profile
        source ~/.bash_profile
        echo -e "${GREEN}Instalando CLI da AWS${NC}"
        pip install awscli --upgrade --user
        ;;
      'WindowsNT')
        echo -e "${YELLOW}Instalação em sistemas windows não é possível pela liha de comando."
        echo -e "Por favor acesse o site oficial http://docs.aws.amazon.com/cli/latest/userguide/awscli-install-windows.html${NC}"
        exit
        ;;
      'Darwin') 
        echo -e "${CYAN}Obtendo AWS CLI pelo HomeBrew${NC}"
        brew install awscli
        ;;
      *) 
        echo -e "${RED}Tipo de SO não suportado${NC}"
        exit
        ;;
    esac

  else
    echo -e "${CYAN}É necessário instalar o AWS CLI para utilizar o programa${NC}"
    exit
  fi

else
  echo -e "${GREEN}AWS CLI está instalado :)${NC}"
fi










## SELEÇÃO DE REGIÃO ##
#Checa se a região está vazia
if [ -z $region ]; then
  echo -e "Selecione a região: "
  echo -e "1) Producao"
  echo -e "2) Desenvolvimento"
  read region
  # Checa se o usuário digitou de novo a região vazia'
  if [ -z $region ]; then
    echo -e "Opção Inválida: ${RED}Região${NC}" >&2
    exit;
  fi

  case $region in
    "1")
      region="us-east-2"
      ;;
    "2")
      region="us-east-1"
      ;;
    *)
      echo -e "Opção Inválida: ${RED}Região${NC}" >&2
      exec "$0" "$@"
      ;;
  esac
fi





## SELEÇÃO DA INSTANCIA ##

prompt="n"

# Se o usuário passar uma instancia nas flags, ignora o prompt
if [ ! -z $instance ] ; then
  prompt="Y"
  getInstanceName $instance $region
fi

while [ "$prompt" == "n" ]
do
  instance=""
  # Lista máquinas direto da aws
  if [ -z $instance ]; then
    echo -e "${CYAN}Carregando lista de máquinas para $region...${NC}"
    echo -e "$(aws ec2 describe-instances --region $region --query "Reservations[*].Instances[*].['${GREEN}+----', InstanceId, '----+${NC}', Tags[?Key=='Name']]" --output text)"
    echo "Digite o id da instancia: "
    read instance

    if [ -z $instance ]; then
      echo -e "Opção Inválida: ${RED}ID da instancia${NC}" >&2
      exit
    fi
  fi

  now="$(date +'%Y%m%d')"
  getInstanceName $instance $region

  echo -e "${LIGHTRED}Você está prestes a criar uma imagem para a máquina ${YELLOW}$instance_name${NC}, ${LIGHTRED}deseja prosseguir? [Y,n]${NC}"
  read prompt
  prompt=${prompt:-"Y"}
done





## EXECUÇÃO ##
echo -e "${YELLOW}Executando comando de criação de imagem para a instancia $instance ($instance_name)${NC}"

aws ec2 create-image $dry_run --name "AMI-$instance_name-$now" --instance-id $instance --no-reboot --region $region --description "Imagem criada pelo sistema de imagem automatica em $(date +'%d-%m-%Y %H:%M:%S')"

echo -e "${CYAN}Criar outra imagem? [y,N]${NC}"
read prompt
prompt=${prompt:-"n"}

case "$prompt" in
  [nN])
    echo -e "${CYAN}Até logo :)${NC}"
    exit
    ;;
  [yY])
    exec "$0" "$@"
    ;;
  *)
    exit
    ;;
esac
