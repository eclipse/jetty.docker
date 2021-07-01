#!/bin/bash

greaterThanOrEqualTo9.4 ()
{
	# If version is not numerical it cannot be compared properly.
	if [[ ! $1 =~ ^[0-9]+\.?[0-9]*$ ]]; then
		echo "Invalid version $1"
		exit 1
	fi

	# Compare version numerically using awk.
	if awk 'BEGIN{exit ARGV[1]>=ARGV[2]}' "$1" "9.4"; then
		return 1
	else
		return 0
	fi
}

# Update the Travis CI Build Directories
if ! command -v ./generateTravis.sh >/dev/null 2>&1 ; then
	echo "WARNING: Run update script from the jetty.docker project directory to update the Travis CI file."
else
	./generateTravis.sh > .travis.yml
fi

# Update the docker files and scripts for every directory in paths.
paths=( "$@" )
if [ ${#paths[@]} -eq 0 ]; then
	paths=( $(ls | egrep '^[0-9]' | sort -nr) )
fi
paths=( "${paths[@]%/}" )

for path in "${paths[@]}"; do
	version="${path%%-*}" # "9.2"
	jvm="${path#*-}" # "jre11-slim"
	disto=$(expr "$jvm" : '\(j..\)[0-9].*') # jre
	variant=$(expr "$jvm" : '.*-\(.*\)') # slim
	release=$(expr "$jvm" : 'j..\([0-9][0-9]*\).*') # 11
	label=${release}-${disto}${variant:+-$variant} # 11-jre-slim

	if [ -d "$path" ]; then
		if [[ "$version" == "9.4" ]]; then
			fullVersion="9.4.43.v20210629"
			stagingNumber="1684"
		fi
		if [[ "$version" == "10.0" ]]; then
			fullVersion="10.0.6"
			stagingNumber="1682"
		fi
		if [[ "$version" == "11.0" ]]; then
			fullVersion="11.0.6"
			stagingNumber="1683"
		fi

		if greaterThanOrEqualTo9.4 "${version}"; then
			jettyHomeUrl="https://oss.sonatype.org/content/repositories/jetty-$stagingNumber/org/eclipse/jetty/jetty-home/$fullVersion/jetty-home-$fullVersion.tar.gz"
			cp docker-entrypoint.sh generate-jetty-start.sh "$path"

			# Generate the Dockerfile in the directory for this version.
			echo "# DO NOT EDIT. Edit baseDockerfile${variant:+-$variant} and use update.sh" >"$path"/Dockerfile
			cat "baseDockerfile${variant:+-$variant}" >>"$path"/Dockerfile

			# Set the Jetty and JDK/JRE versions in the generated Dockerfile.
			sed -ri 's/^(ENV JETTY_VERSION) .*/\1 '"$fullVersion"'/; ' "$path/Dockerfile"
			sed -ri 's|^(ENV JETTY_TGZ_URL) .*|\1 '"$jettyHomeUrl"'|; ' "$path/Dockerfile"
			sed -ri 's/^(FROM openjdk:)LABEL/\1'"$label"'/; ' "$path/Dockerfile"
		fi
	fi
done
