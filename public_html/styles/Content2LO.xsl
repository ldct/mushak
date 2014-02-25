<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:mooshak="http://www.ncc.up.pt/mooshak/"
	xmlns="http://www.imsglobal.org/xsd/imscp_v1p1" xmlns:imsmd="http://www.imsglobal.org/xsd/imsmd_v1p2"
	xmlns:ejmd="http://www.edujudge.eu/ejmd_v2" 
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

	<xsl:output indent="yes" encoding="UTF-8" method="xml" />

	<xsl:param name="title"></xsl:param>
	<xsl:param name="language">en-GB</xsl:param>
	<xsl:param name="author">Unknown author</xsl:param>
	<xsl:param name="date"></xsl:param>
	<xsl:param name="difficulty"></xsl:param>
	<xsl:param name="type"></xsl:param>
	<xsl:param name="id"></xsl:param>
	<xsl:param name="compile"></xsl:param>
	<xsl:param name="execute"></xsl:param>
	<xsl:param name="programmingLanguage"></xsl:param>
	<xsl:param name="programmingLanguageVersion"></xsl:param>


	<xsl:template match="mooshak:Problem">

		<manifest identifier="MANIFEST-00001"
			xsi:schemaLocation="
			 http://www.imsglobal.org/xsd/imscp_v1p1   imscp_v1p1.xsd 
			 http://www.imsglobal.org/xsd/imsmd_v1p2   imsmd_v1p2p4.xsd 
			 http://www.edujudge.eu/ejmd_v2            ejmd_v2.xsd">

			<xsl:call-template name="metadata" />
			<xsl:call-template name="organizations" />
			<xsl:call-template name="resources" />
		</manifest>

	</xsl:template>

	<xsl:template name="metadata">
		<metadata>
			<schema>IMS Content</schema>
			<schemaversion>1.1</schemaversion>
			<xsl:call-template name="lom-metadata" />
			<xsl:call-template name="ejmd-metadata" />
		</metadata>

	</xsl:template>

	<xsl:template name="lom-metadata">
		<imsmd:lom>
			<imsmd:general>
				<imsmd:identifier><xsl:value-of select="$id"/></imsmd:identifier>
				<imsmd:title>
					<imsmd:langstring xml:lang="{$language}"><xsl:value-of select="$title"/></imsmd:langstring>
				</imsmd:title>
				<imsmd:language>
					<xsl:value-of select="$language" />
				</imsmd:language>
				<imsmd:description>
					<imsmd:langstring xml:lang="{$language}">A programming problem</imsmd:langstring>
				</imsmd:description>
				<imsmd:keyword>
					<imsmd:langstring xml:lang="{$language}"></imsmd:langstring>
				</imsmd:keyword>
			</imsmd:general>
			<imsmd:lifecycle>
				<imsmd:version>
					<imsmd:langstring xml:lang="en">1.0</imsmd:langstring>
				</imsmd:version>
				<imsmd:status>
					<imsmd:source>
						<imsmd:langstring xml:lang="en">LOMv1.0</imsmd:langstring>
					</imsmd:source>
					<imsmd:value>
						<imsmd:langstring xml:lang="en">final</imsmd:langstring>
					</imsmd:value>
				</imsmd:status>
				<imsmd:contribute>
					<imsmd:role>
						<imsmd:source>
							<imsmd:langstring xml:lang="en">LOMv1.0</imsmd:langstring>
						</imsmd:source>
						<imsmd:value>
							<imsmd:langstring xml:lang="en">Author</imsmd:langstring>
						</imsmd:value>
					</imsmd:role>
					<imsmd:centity>
						<imsmd:vcard>BEGIN:VCARD FN:<xsl:value-of select="$author"/> END:VCARD</imsmd:vcard>
					</imsmd:centity>
					<imsmd:date>
						<imsmd:datetime><xsl:value-of select="$date"/></imsmd:datetime>
					</imsmd:date>
				</imsmd:contribute>
			</imsmd:lifecycle>
			<imsmd:technical>
				<imsmd:format>text/html</imsmd:format>
				<imsmd:format>text/plain</imsmd:format>
				<imsmd:format>image/gif</imsmd:format>
				<!-- <imsmd:size><xsl:value-of seelct="$size"/></imsmd:size>  -->
				<imsmd:location type="URI"><xsl:value-of select="$id"/></imsmd:location>
				<imsmd:requirement>
					<imsmd:type>
						<imsmd:source>
							<imsmd:langstring xml:lang="x-none">LOMv1.0</imsmd:langstring>
						</imsmd:source>
						<imsmd:value>
							<imsmd:langstring xml:lang="x-none">Browser</imsmd:langstring>
						</imsmd:value>
					</imsmd:type>
					<imsmd:name>
						<imsmd:source>
							<imsmd:langstring xml:lang="x-none">LOMv1.0</imsmd:langstring>
						</imsmd:source>
						<imsmd:value>
							<imsmd:langstring xml:lang="x-none">Opera</imsmd:langstring>
						</imsmd:value>
					</imsmd:name>
					<imsmd:minimumversion>1.0</imsmd:minimumversion>
					<imsmd:maximumversion>3.0</imsmd:maximumversion>
				</imsmd:requirement>
			</imsmd:technical>
			<imsmd:educational>
				<imsmd:interactivitytype>
					<imsmd:source>
						<imsmd:langstring xml:lang="x-none">LOMv1.0</imsmd:langstring>
					</imsmd:source>
					<imsmd:value>
						<imsmd:langstring xml:lang="x-none">active</imsmd:langstring>
					</imsmd:value>
				</imsmd:interactivitytype>
				<imsmd:learningresourcetype>
					<imsmd:source>
						<imsmd:langstring xml:lang="x-none">LOMv1.0</imsmd:langstring>
					</imsmd:source>
					<imsmd:value>
						<imsmd:langstring xml:lang="x-none">exercise</imsmd:langstring>
					</imsmd:value>
				</imsmd:learningresourcetype>
				<imsmd:interactivitylevel>
					<imsmd:source>
						<imsmd:langstring xml:lang="x-none">LOMv1.0</imsmd:langstring>
					</imsmd:source>
					<imsmd:value>
						<imsmd:langstring xml:lang="x-none">low</imsmd:langstring>
					</imsmd:value>
				</imsmd:interactivitylevel>
				<imsmd:intendedenduserrole>
					<imsmd:source>
						<imsmd:langstring xml:lang="x-none">LOMv1.0</imsmd:langstring>
					</imsmd:source>
					<imsmd:value>
						<imsmd:langstring xml:lang="x-none">learner</imsmd:langstring>
					</imsmd:value>
				</imsmd:intendedenduserrole>
				<imsmd:context>
					<imsmd:source>
						<imsmd:langstring xml:lang="x-none">LOMv1.0</imsmd:langstring>
					</imsmd:source>
					<imsmd:value>
						<imsmd:langstring xml:lang="en">Higher Education</imsmd:langstring>
					</imsmd:value>
				</imsmd:context>
				<imsmd:typicalagerange>
					<imsmd:langstring xml:lang="en">19-21</imsmd:langstring>
				</imsmd:typicalagerange>
				<imsmd:difficulty>
					<imsmd:source>
						<imsmd:langstring xml:lang="x-none">LOMv1.0</imsmd:langstring>
					</imsmd:source>
					<imsmd:value>
						<imsmd:langstring xml:lang="en"><xsl:value-of select="$difficulty"/></imsmd:langstring>
					</imsmd:value>
				</imsmd:difficulty>
				<imsmd:typicallearningtime>
					<imsmd:datetime></imsmd:datetime>
				</imsmd:typicallearningtime>
				<imsmd:description>
					<imsmd:langstring xml:lang="en">Follow the problem description</imsmd:langstring>
				</imsmd:description>
				<imsmd:language>
					<xsl:value-of select="$language" />
				</imsmd:language>

			</imsmd:educational>
			<imsmd:rights>
				<imsmd:cost>
					<imsmd:source>
						<imsmd:langstring xml:lang="x-none">LOMv1.0</imsmd:langstring>
					</imsmd:source>
					<imsmd:value>
						<imsmd:langstring xml:lang="x-none">no</imsmd:langstring>
					</imsmd:value>
				</imsmd:cost>
				<imsmd:copyrightandotherrestrictions>
					<imsmd:source>
						<imsmd:langstring xml:lang="en">LOMv1.0</imsmd:langstring>
					</imsmd:source>
					<imsmd:value>
						<imsmd:langstring xml:lang="en">no</imsmd:langstring>
					</imsmd:value>
				</imsmd:copyrightandotherrestrictions>
				<imsmd:description>
					<imsmd:langstring xml:lang="en">No license</imsmd:langstring>
				</imsmd:description>
			</imsmd:rights>
			<imsmd:classification>
				<imsmd:purpose>
					<imsmd:source>
						<imsmd:langstring xml:lang="en">LOMv1.0</imsmd:langstring>
					</imsmd:source>
					<imsmd:value>
						<imsmd:langstring xml:lang="en">Discipline</imsmd:langstring>
					</imsmd:value>
				</imsmd:purpose>
				<imsmd:keyword>
					<imsmd:langstring xml:lang="en"><xsl:value-of select="$type"/></imsmd:langstring>
				</imsmd:keyword>
			</imsmd:classification>
		</imsmd:lom>

	</xsl:template>

	<xsl:template name="ejmd-metadata">
		<ejmd:metadata>
			<ejmd:general>
				<ejmd:hints>
					<ejmd:submission ejmd:time-solve="PT15M"
						ejmd:time-submit="PT1M" ejmd:attempts="3" ejmd:code-lines="30"
						ejmd:length="1000" />
					<ejmd:compilation ejmd:time="PT1M" ejmd:size="1000" />
					<ejmd:execution ejmd:time="PT1M" />
				</ejmd:hints>
			</ejmd:general>
			<ejmd:presentation>
				<ejmd:description ejmd:resource="DESCRIPTION" />
			</ejmd:presentation>
			<ejmd:evaluation ejmd:evaluationModel="ICPC" ejmd:evaluationModelVersion="1">
				<ejmd:tests>
					<xsl:for-each select="mooshak:Tests/mooshak:Test">
						<ejmd:testFiles ejmd:arguments=""
							ejmd:valorization="20">
							<ejmd:input ejmd:resource="INPUT-{position()}" />
							<ejmd:output ejmd:resource="OUTPUT-{position()}" />
						</ejmd:testFiles>
					</xsl:for-each>
				</ejmd:tests>
				<!-- CHECK THIS !! -->
				<ejmd:solution ejmd:resource="SOLUTION"
					ejmd:compilationLine="{$compile}"
					ejmd:executionLine="{$execute}" ejmd:language="{$programmingLanguage}"
					ejmd:languageVersion="{$programmingLanguageVersion}" />
			</ejmd:evaluation>
		</ejmd:metadata>
	</xsl:template>

	<xsl:template name="organizations">
		<organizations />
	</xsl:template>

	<xsl:template name="resources">
		<resources>
			<resource identifier="DESCRIPTION" type="webcontent"
				      href="{@Description}">
				<file href="{@Description}">
					<metadata>
						<imsmd:lom>
							<imsmd:general>
								<imsmd:language>
									<xsl:value-of select="$language" />
								</imsmd:language>
							</imsmd:general>
							<imsmd:technical>
								<imsmd:format>text/html</imsmd:format>
								<!-- <imsmd:size> ? </imsmd:size>  -->
							</imsmd:technical>
						</imsmd:lom>
					</metadata>
				</file>
				<xsl:for-each select="mooshak:Images">
					<file href="images/{@Image}" />
				</xsl:for-each>
			</resource>
			<resource identifier="SOLUTION" type="SOLUTION">
				<file href="{@Program}" />
			</resource>
			<xsl:for-each select="mooshak:Tests/mooshak:Test">
				<xsl:variable name="dir">
					<xsl:value-of select="translate(@xml:id,'.','/')" />
				</xsl:variable>
				<resource identifier="INPUT-{position()}" type="INPUT">
					<file href="{$dir}/{@input}" />
				</resource>
				<resource identifier="OUTPUT-{position()}" type="OUTPUT">
					<file href="{$dir}/{@output}" />
				</resource>
			</xsl:for-each>

		</resources>
	</xsl:template>

</xsl:stylesheet>