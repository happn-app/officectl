FROM debian:stretch-slim

        LABEL maintainer="sami.nacer@happn.fr"

#Ajout des libs

        RUN apt-get -qy update && apt-get -qy install libldap-2.4-2 && \
            apt-get -qy install libssl1.0.2 && apt-get -qy install zlib1g && apt-get -qy install libncurses-dev

#Ajout de swiftlang-lib

        COPY /linux_build/products/swift_debs/swiftlang-libs_5.2.4-RELEASE-1~mkdeb1_amd64.deb  /tmp/linux_build/products/swift_debs/swiftlang-libs_5.2.4-RELEASE-1~mkdeb1_amd64.deb

        RUN apt-get -qy install libatomic1 && apt-get -qy install libbsd0 && apt-get -qy install libcurl3 && apt-get -qy install libicu57 && apt-get -qy install libxml2 \
        dpkg  /tmp/linux_build/products/swift_debs/swiftlang-libs_5.2.4-RELEASE-1~mkdeb1_amd64.deb

#Ajout d'officectl en Binaire

	COPY /linux_build/products/release/officectl /usr/local/bin/officectl

	ADD /Public /usr/local/share/officectl/Public

	ADD /Resources /usr/local/share/officectl/Resources

	CMD  /usr/local/bin/officectl
