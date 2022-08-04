#!/usr/bin/env bash

usage(){
    echo "Usage: $0 [-p <profile>] [-c] [-v] [-r <region>] [-t <type>] [-h] [-d] [-s] <stack name>"
    echo "       -p <profile> specify the AWS profile to use (Default=\"default\")"
    echo "       -c <yes|no> (default=no) Continue from previous run"
    echo "       -r <region>  specify the AWS region to use (Default=the aws command line setting)"
    echo "       -v <yes|no> (default=no) Stop after terraform validate step"
    echo "       -h           Help - this message"
    echo "       -d <yes|no|st> (default=no)   Debug - lots of output if yes"
    echo "       -s <stack name>  Traverse a Stack and import resources (experimental)"
    echo "       -t <type>   choose a sub-type of AWS resources to get:"
    echo "           appmesh"
    echo "           appstream"
    echo "           athena"
    echo "           cf"
    echo "           org"
    echo "           code"
    echo "           iam"
    echo "           kms"
    echo "           lambda"
    echo "           ecs"
    echo "           eks"
    echo "           emr"
    echo "           lf"
    echo "           glue"
    echo "           params"
    echo "           eb"
    echo "           ec2"
    echo "           rds"
    echo "           s3"
    echo "           secrets"
    echo "           sagemaker"
    echo "           sc"
    echo "           spot"
    echo "           sqs"
    echo "           tgw"
    echo "           vpc"
    exit 1
}

x="no"
p="default" # profile
f="no"
v="no"
r="no" # region
c="no" # combine mode
d="no"
s="no"

while getopts ":p:r:x:f:v:t:i:c:d:h:s:" o; do
    case "${o}" in
        h) usage
        ;;
        i) i=${OPTARG}
        ;;
        t) t=${OPTARG}
        ;;
        r) r=${OPTARG}
        ;;
        x) x="yes"
        ;;
        p) p=${OPTARG}
        ;;
        f) f="yes"
        ;;
        v) v="yes"
        ;;
        c) c="yes"
        ;;
        d) d=${OPTARG}
        ;;
        s) s=${OPTARG}
        ;;
        
        *)
            usage
        ;;
    esac
done
shift $((OPTIND-1))

trap ctrl_c INT

function ctrl_c() {
        echo "Requested to stop."
        exit 1
}

if [ "$d" = "yes" ]; then
    set -x
    echo "CAUTION - lots of output, potentially including sensitive information"
fi

if [ ! -z ${AWS_PROFILE+x} ];then
    p=`echo $AWS_PROFILE`
    echo "profile $AWS_PROFILE set from env variables"
fi

export aws2tfmess="# File generated by aws2tf see https://github.com/aws-samples/aws2tf"

if [ -z ${AWS_ACCESS_KEY_ID+x} ] && [ -z ${AWS_SECRET_ACCESS_KEY+x} ];then
    mysub=`aws sts get-caller-identity --profile $p | jq .Account | tr -d '"'`
else
    mysub=`aws sts get-caller-identity | jq .Account | tr -d '"'`
fi

if [ "$r" = "no" ]; then

    if [ ! -z ${AWS_DEFAULT_REGION+x} ];then
        r=`echo $AWS_DEFAULT_REGION`
        echo "region $AWS_DEFAULT_REGION set from env variable AWS_DEFAULT_REGION"
    fi

    if [ ! -z ${AWS_REGION+x} ];then
        r=`echo $AWS_REGION`
        echo "region $AWS_REGION set from env variable AWS_REGION"
    fi
    if [ "$r" = "no" ]; then
        r=`aws configure get region`
        echo "Getting reegion from aws cli = $r"
    fi
fi

if [ "$mysub" == "null" ] || [ "$mysub" == "" ]; then
    echo "Account is null exiting"
    exit
fi

#s=`echo $mysub`
mkdir -p  generated/tf.${mysub}_${r}
cd generated/tf.${mysub}_${r}


if [ "$f" = "no" ]; then
    if [ "$c" = "no" ]; then
        echo "Cleaning generated/tf.${mysub}_${r}"
        rm -f *.txt *.sh *.log *.sav *.zip
        rm -f *.tf *.json *.tmp 
        rm -f terraform.* tfplan 
        rm -rf .terraform data aws_* pi2
    fi
else
    sort -u data/processed.txt > data/pt.txt
    cp pt.txt data/processed.txt
    rm -f terra*.backup
fi

mkdir -p data

rm -f import.log
#if [ "$f" = "no" ]; then
#    ../../scripts/resources.sh 2>&1 | tee -a import.log
#fi


export AWS="aws --profile $p --region $r --output json "
echo " "
echo "Account ID = ${mysub}"
echo "Region = ${r}"
echo "AWS Profile = ${p}"
echo "Extract KMS Secrets to .tf files (insecure) = ${x}"
echo "Fast Forward = ${f}"
echo "Verify only = ${v}"
echo "Type filter = ${t}"
echo "Combine = ${c}"
echo "AWS command = ${AWS}"
echo " "


# cleanup from any previous runs
#rm -f terraform*.backup
#rm -f terraform.tfstate
#rm -f tf*.sh


# write the aws.tf file
printf "terraform { \n" > aws.tf
printf "required_version = \"~> 1.2.0\"\n" >> aws.tf
printf "  required_providers {\n" >> aws.tf
printf "   aws = {\n" >> aws.tf
printf "     source  = \"hashicorp/aws\"\n" >> aws.tf
printf "      version = \"= 4.24.0\"\n" >> aws.tf
#printf "      version = \"= 3.75.1\"\n" >> aws.tf
printf "    }\n" >> aws.tf

#printf "       awscc = {\n" >> aws.tf
#printf "         source  = \"hashicorp/awscc\"\n" >> aws.tf
#printf "         version = \"~> 0.19.0\"\n" >> aws.tf
#printf "       }\n" >> aws.tf
printf "  }\n" >> aws.tf
printf "}\n" >> aws.tf
printf "\n" >> aws.tf
printf "provider \"aws\" {\n" >> aws.tf
printf " region = \"%s\" \n" $r >> aws.tf
if [ -z ${AWS_ACCESS_KEY_ID+x} ] && [ -z ${AWS_SECRET_ACCESS_KEY+x} ];then
    printf " shared_credentials_files = [\"~/.aws/credentials\"] \n"  >> aws.tf
    #printf " shared_credentials_file = \"~/.aws/credentials\" \n"  >> aws.tf
    printf " profile = \"%s\" \n" $p >> aws.tf
    export AWS="aws --profile $p --region $r --output json "
else
    export AWS="aws --region $r --output json "
fi
printf "}\n" >> aws.tf
#printf "provider \"awscc\" {\n" >> aws.tf
#printf " region = \"%s\" \n" $r >> aws.tf
#printf "}\n" >> aws.tf

export AWS2TF_REGION=`echo $r`
export AWS2TF_ACCOUNT=`echo $mysub`

cat aws.tf
cp ../../stubs/data*.tf .

if [ "$t" == "no" ]; then t="*"; fi

pre="*"
if [ "$t" == "vpc" ]; then
    pre="1*"
    t="*"
    if [ "$i" == "no" ]; then
        echo "VPC Id null exiting - specify with -i <vpc-id>"
        exit
    fi
fi

if [ "$t" == "tgw" ]; then
    pre="type"
    t="transitgw"
    if [ "$i" == "no" ]; then
        echo "TGW Id null exiting - specify with -i <tgw-id>"
        exiting
    fi
fi


if [ "$t" == "ecs" ]; then
    pre="3*"
    if [ "$i" == "no" ]; then
        echo "Cluster Name null exiting - specify with -i <cluster-name>"
        exit
    fi
fi


if [ "$t" == "eks" ]; then
    pre="30*"
    if [ "$i" == "no" ]; then
        echo "Cluster Name null exiting - specify with -i <cluster-name>"
        exit
    fi
fi
if [ "$t" == "apigw" ]; then pre="75*"; fi
if [ "$t" == "appmesh" ]; then pre="360*"; fi
if [ "$t" == "appstream" ]; then pre="46*"; fi
if [ "$t" == "artifact" ]; then pre="627*"; fi
if [ "$t" == "athena" ]; then pre="66*"; fi
if [ "$t" == "code" ]; then pre="625*"; fi
if [ "$t" == "cfront" ]; then pre="80*"; fi
if [ "$t" == "cloudform" ]; then pre="999*"; fi
if [ "$t" == "cognito" ]; then pre="77*"; fi
if [ "$t" == "config" ]; then pre="41*"; fi
if [ "$t" == "eb" ]; then pre="71*"; fi
if [ "$t" == "ec2" ]; then pre="25*"; fi
if [ "$t" == "emr" ]; then pre="37*"; fi
if [ "$t" == "glue" ]; then pre="65*"; fi
if [ "$t" == "kinesis" ]; then pre="74*"; fi
if [ "$t" == "kms" ]; then pre="08*"; fi
if [ "$t" == "lambda" ]; then pre="700*"; fi
if [ "$t" == "lf" ]; then pre="63*"; fi
if [ "$t" == "org" ]; then pre="01*"; fi
if [ "$t" == "params" ]; then pre="445*"; fi
if [ "$t" == "rds" ]; then pre="60*"; fi
if [ "$t" == "s3" ]; then pre="060*"; fi # change to 06*
if [ "$t" == "sagemaker" ]; then pre="68*"; fi
if [ "$t" == "secrets" ]; then pre="45*"; fi
if [ "$t" == "sc" ]; then pre="81*"; fi # service catalog
if [ "$t" == "sqs" ]; then pre="72*"; fi # SQS
if [ "$t" == "spot" ]; then pre="25*"; fi


exclude="iam"

if [ "$t" == "iam" ]; then pre="05*" && exclude="xxxxxxx"; fi

if [ "$c" == "no" ]; then
    echo "terraform init -upgrade"
    terraform init -upgrade -no-color 2>&1 | tee -a import.log
fi
pwd
ls
#############################################################################
date
lc=0
if [[ "$s" == "no" ]];then 
echo "t=$t pre=$pre i=$i exclude=$exclude"
echo "loop through providers"
tstart=`date +%s`
for com in `ls ../../scripts/$pre-get-*$t*.sh | cut -d'/' -f4 | sort -g`; do    
    start=`date +%s`
    if [[ "$com" == *"${exclude}"* ]]; then
        echo "skipping $com"
    else
        docomm=". ../../scripts/$com $i"
        echo $docomm
        if [ "$f" = "no" ]; then
            eval $docomm 2>&1 | tee -a import.log
        else
            grep "$docomm" data/processed.txt
            if [ $? -eq 0 ]; then
                echo "skipping $docomm"
            else
                eval $docomm 2>&1 | tee -a import.log
            fi
        fi
        lc=`expr $lc + 1`

        file="import.log"
        while IFS= read -r line
        do
            if [[ "${line}" == *"Error"* ]];then
          
                if [[ "${line}" == *"Duplicate"* ]];then
                    echo "Ignoring $line"
                else
                    if [[ "$d" == "no" ]];then
                        echo "Found Error: $line .... (pass for now)"
                    else
                        echo "Found Error: $line exiting ...."
                        exit
                    fi
                fi
            fi

        done <"$file"

        echo "$docomm" >> data/processed.txt
        terraform fmt
        terraform validate -no-color
        end=`date +%s`
        runtime=$((end-start))
        echo "$com runtime $runtime seconds"
    fi
    
done
else
    echo "Stack set $s traverse - experimental"
    . ../../scripts/get-stack.sh $s
    chmod 755 commands.sh
  
    if [ "$d" = "st" ]; then  exit; fi
    . ./commands.sh
    echo "commands done - was unable to process:"
    cat unprocessed.log
fi

#########################################################################
tend=`date +%s`
truntime=$((tend-tstart))
echo "Total runtime in seconds $truntime"

date

echo "terraform fmt > /dev/null ..."
terraform fmt > /dev/null
terraform refresh  -no-color
echo "fix default SG's"
. ../../scripts/fix-def-sgs.sh
echo "Terraform validate ..."
terraform validate -no-color


if [ "$v" = "yes" ]; then
    exit
fi
if [ "$d" = "no" ]; then
    echo "skip clean"
    #rm -f *.txt imp*.sh
fi

echo "Terraform Refresh ..."


echo "Terraform Plan ..."
terraform plan -no-color

echo "---------------------------------------------------------------------------"
echo "aws2tf output files are in generated/tf.${mysub}_${r}"
echo "---------------------------------------------------------------------------"

if [ "$t" == "eks" ]; then
echo "aws eks update-kubeconfig --name $i"
fi