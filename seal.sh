SECRETS=$(find . -name "secret*.yaml")
REPO=$(basename -s .git `git config --get remote.origin.url`)

for f in $SECRETS; do 
    echo "Sealing $f"
    kubeseal --cert http://192.168.1.118:8080/v1/cert.pem --scope namespace-wide --namespace $REPO --allow-empty-data --format yaml < $f > $(dirname -- "$f")/sealed-$(basename "$f")
done