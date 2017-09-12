require 'nokogiri'
require 'open-uri'
require 'pry'
require 'mechanize'
require 'capybara'
require 'capybara/poltergeist'
Capybara.javascript_driver = :poltergeist

# Scraper to get evaluation of inacap
class Inacap
  BASE_URL = 'https://adfs.inacap.cl/adfs/ls/?wtrealm=https://siga.inacap.cl/sts/&wa=wsignin1.0&wreply=https://siga.inacap.cl/sts/&wctx=https%3a%2f%2fadfs.inacap.cl%2fadfs%2fls%2f%3fwreply%3dhttps%3a%2f%2fwww.inacap.cl%2ftportalvp%2fintranet-alumno%26wtrealm%3dhttps%3a%2f%2fwww.inacap.cl%2f'

  def initialize(email, pass)
    @email = email
    @pass = pass
  end

  def response_sign_in
    agent = Mechanize.new
    page_auth = agent.get(BASE_URL)
    form_inacap = page_auth.form

    form_inacap.field_with(type: 'email').value = @email
    form_inacap.field_with(type: 'password').value = @pass

    first_return = agent.submit(form_inacap)
    second_return = agent.submit(first_return.form)
    third_return = agent.submit(second_return.form)

    third_return
  end

  def current_evaluations
    home_page = response_sign_in
    action_note = home_page.links[51].click
    notes_url = action_note.uri
    session = Capybara::Session.new(:poltergeist)

    session.visit(notes_url)
    sleep(1)

    notes_page = Nokogiri::HTML(session.html)
    info_sub = info_subject(notes_page.search('.panel-body'))
    sub = subjects(notes_page.search('.panel-heading'))
    eva = evaluations(notes_page.search('table tbody'))
    current = merge_info(sub, info_sub, eva)
    binding.pry
  end

  def merge_info(sub, info_sub, eva)
    object = sub.each_with_index do |subject, i|
      subject[:info_subject] = info_sub[i]
      subject[:evaluations] = eva[i]
    end
  end

  def split_subject(doc)
    subj = []
    doc.each { |e| subj << e.text.split(' - ') }
    subj
  end

  def subjects(doc)
    subj = split_subject(doc)
    subject = []

    subj.each { |e| subject << attr_subjet(e) }

    subject
  end

  def attr_subjet(params)
    {
      subject: params[0],
      departament_cod: params[1],
      division: params[2].gsub('SECCIÓN ', ''),
      info_subject: nil,
      evaluations: nil
    }
  end

  def attr_info_worshop(params)
    {
      teacher_name: params[0].children[2].text.to_s,
      date_last_class: params[1].children[2].text.to_s,
      presentation_note: params[2].children[2].text.to_f,
      final_note: params[3].children[2].text.to_f,
      assistance: params[4].children[2].text.to_s,
      final_status: params[5].children[2].text.to_s
    }
  end

  def attr_info_subject(params)
    {
      teacher_name: params[0].children[2].text.to_s,
      date_exam: params[1].children[2].text.to_s,
      date_last_class: params[2].children[2].text.to_s,
      presentation_note: params[3].children[2].text.to_f,
      exam_note: params[4].children[2].text.to_f,
      final_note: params[5].children[2].text.to_f,
      assistance: params[6].children[2].text.to_s,
      final_status: params[7].children[2].text.to_s
    }
  end

  def attr_evaluation(params)
    {
      method: params.children[1].text.to_s,
      percentage: params.children[2].text.to_s,
      date: params.children[3].text.to_s,
      score: params.children[4].text.to_f,
      course_score: params.children[5].text.to_f
    }
  end

  def evaluations(doc)
    evaluation = []
    eval = doc.to_a.reject { |v| doc.to_a.index(v).odd? }
    eval.each do |e|
      arr = []
      e.children.each { |u| arr << attr_evaluation(u) }
      evaluation << arr
    end
    evaluation
  end

  def info_subject(doc)
    info = []
    doc.each do |e|
      info << attr_info_subject(e.css('div div p')) if e.css('div div p').count == 8
      info << attr_info_worshop(e.css('div div p')) if e.css('div div p').count == 6
    end
    info
  end
end
