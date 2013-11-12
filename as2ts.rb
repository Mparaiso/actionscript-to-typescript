=begin
 As2ts 
 Convert AS3 files into Typescript files
 @author mparaiso <mparaiso@online.fr>  
=end

require "fileutils"

class As2ts

  @@rules = [
    [/package/,"module"],
    [/(int|uint|Number)(?![\( \.])/,"Number"],
    [/String(?![ \( \.])/,"string"],
    [/Boolean(?![\( \.])/,"boolean"],
    [/const/,""],
    [/(public|private|protected) var/,""],
    [/(public|private|protected) function/,""],
    [/(public|private|protected) interface/,"export interface"],
    [/(public|private|protected) class/,"export class"],
    [ /import(.*)(?:\.)(\w+)(\.\w+)(?:;)/,'import \2 = \1.\2 ;'],
    [/override/,""],
    [/(?:\:)Object/,":any"],
    [/\:\*/,":any"],
    [/\sis\s/,"instanceof"],
    [/(\w+) (as) (\w+)/,'<\3>\1'],
    [/(for.*\(.*var.*\w+)(?:\:)(\w+)/,'\1']
  ]

  @@commentRule=[/\/\*(.*?)\*\//m,""]

  def self.directoryExistOrThrow(directory)
    if not Dir.exist? directory then throw "Directory #{inputDir} doesnt exist" end
  end

  def self.fileExistOrTrhow(file)
    if not File.exist?(file) then throw "File #{file} does not exist" end
  end

  def self.diretoryExistOrCreate(directory)
    #p directory
    if not Dir.exist?(directory) then FileUtils.mkdir_p directory end
  end

  #convertir un répertoire de fichier as3 en fichiers typescript
  def self.convertDirectory(inputDir=".",outputDir="./output",debug=false)
    self.directoryExistOrThrow(inputDir)
    self.diretoryExistOrCreate(outputDir)
    filepaths = Dir.glob(File.join(inputDir,'**','*.as'))
    filepaths.each do |file|
      if debug then p "converting file #{file}" end
      self.convertFile(file,File.join(outputDir,file.gsub(/\.as/,'.ts')))
    end
    definitions = ""
    filepaths.each do |file|
      definitions << "///<reference path='#{file.gsub(/.as/,'.ts')}'/>\n"
    end
    
    definition_file = File.new(File.join(outputDir,"definitions.ts"),"w")
    definition_file.syswrite(definitions)
    if debug then p "creating definition file #{definition_file.path}" end
    definition_file.close
      
  end

  # effacer les commentaires
  def self.stripComments(aString)
    return aString.gsub @@commentRule[0],@@commentRule[1]
  end

  # ajoute un namespace aux classes importées
  def self.convertImports(aString,anArray)
    content=""
    aString.split('\n').map do |line|
      anArray.map do |el|
        _class = el.gsub(/.*(?:\.)(\w+)/,'\1').strip
        line.gsub!( /(?!:import.*)(\W)(#{_class})/ , '\1'+el )
      end
      content << line
    end
    content
  end

  # obtenir les imports
  def self.getImports(aFileResource)
    aFileResource.rewind()
    File.readlines(aFileResource).map{|l| /import.*(?:\.)(\w+\.\w+)(?:;)/.match(l)}.compact.map{|a| a[1]}
  end

  # créer un fichier typescript à partir d'un chemin de fichier as3
  def self.convertFile(inputFilePath,outputFilePath,debug=false)
    content = self.doConvertFile(inputFilePath,true,debug)
    output = if outputFilePath!=nil then outputFilePath else inputFilePath.sub(/\.as$/,".ts") end
    if debug then p "out: "+ output end
    if debug then p  "content\n" + content end
    self.diretoryExistOrCreate(File.dirname(output))
    file = File.new(output,"w")
    file.syswrite(content)
    file.close
  end

  # obtenir un script typscript à partir d'un chemin de fichier
  def self.doConvertFile(inputFile,stripComments=true,debug=false)
    self.fileExistOrTrhow(inputFile)
    content=""
    imports=nil
    File.open(inputFile) do |file|
      imports = self.getImports(file)
      if debug then p imports end
      file.rewind
      File.readlines(file).each do |line|
        @@rules.each { |rule|
          line.gsub!(rule[0],rule[1])
        }
        content << line
      end
      content=self.convertImports(content,imports)
    end
    if stripComments == true then c = self.stripComments(content) end
    return c
  end

end

if __FILE__== $0
  # parse arguments
  require "optparse"

  options ={:output=>'./output',:verbose=>false,:declaration=>true}

  OptionParser.new do |opts|
    opts.banner = "Usage as2ts.rb -f inputfile"
    opts.on "-f","--file [FILE]","input file" do |f|
      options[:file]=f
    end
    opts.on '-v','--verbose [TRUE]','print many informations' do |v|
      options[:verbose]=true
    end
    opts.on '-d','--directory [INPUT DIRECTORY]','input directory' do |d|
      options[:directory]=d
    end
    opts.on "-o","--output-directory [OUTPUT DIRECTORY]","output directory (default : output)" do |o|
      options[:output]=o||'./output'
    end
    opts.on "-e","--[no-]declaration","generate declaration file" do |d|
      options[:declaration]=d
    end
  end.parse!

  #p options

  #p ARGVF
  if  options[:directory] != nil then
    As2ts.convertDirectory(options[:directory],options[:output],options[:verbose])
  else if options[:file] != nil then
      output = options[:file].gsub /\.as/,'.ts'
      As2ts.convertFile(options[:file],output,options[:verbose],options[:declaration])
    end
  end
end
